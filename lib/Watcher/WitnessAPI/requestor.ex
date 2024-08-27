defmodule Watcher.WitnessClient do
  @moduledoc """
  Defines `WitnessClient` struct
  """
  defstruct controller: nil, talker: nil

  alias Watcher.{TransPreController, WitnessTalker}
  alias Kerilex.Event.Query

  def new(salt, wit_pre, url) do
    ctrl = TransPreController.new(salt)
    {:ok, ctrl} = ctrl |> TransPreController.incept_for(wit_pre)
    talker = WitnessTalker.new(wit_pre, url)

    %__MODULE__{controller: ctrl, talker: talker}
  end

  def controller_pre(%__MODULE__{controller: %TransPreController{pre: pre}}) do
    pre
  end

  def introduce_to_witness(witness_client) when is_struct(witness_client, __MODULE__) do
    %__MODULE__{talker: talker, controller: ctrl} = witness_client
    {icp_msg, cers_att} = ctrl |> TransPreController.icp_data()

    talker |> WitnessTalker.send_request(icp_msg, cers_att)
  end

  def qry_and_poll(witness_client, qry_msg, opts \\ [])
      when is_struct(witness_client, __MODULE__) and qry_msg != "" do
    {ctrl_pre, signer} = witness_client.controller |> TransPreController.pre_and_signer()
    talker = witness_client.talker

    stream =
      Keyword.get(opts, :stream, true)

    with {:ok, cesr_att} <- Query.sign_and_encode_to_cesr(ctrl_pre, [signer], qry_msg),
         :ok <- talker |> WitnessTalker.send_request(qry_msg, cesr_att),
         {:ok, resp} <- WitnessMailbox.Poller.poll(ctrl_pre, talker, stream) do
      if stream do
        :ok
      else
        {:ok, resp}
      end
    else
      {:error, reason} ->
        {:error, "witness=#{talker.wit_pre} qry failed: #{reason}"}
    end
  end
end

defmodule WitnessMailbox.EventHelper do
  alias EventBus.Model.Event

  defmacro __using__(_) do
    quote do
      require WitnessMailbox.EventHelper
      alias WitnessMailbox.EventHelper
      # alias EventBus.Model.Event
    end
  end

  defmacro notify(params, do: yield) do
    quote bind_quoted: [params: params, yield: yield] do
      event = %Event{
        id: :erlang.unique_integer([:positive, :monotonic]),
        topic: Map.fetch!(params, :topic),
        source: Map.get(params, :source),
        occurred_at: :erlang.system_time(:microsecond),
        data: yield
      }

      EventBus.notify(event)
    end
  end
end

defmodule WitnessMailbox.EventProcessor do
  @moduledoc """
  asynchronously parse and post SSE events coming from a Mailbox of a KERI Witness
  """
  use WitnessMailbox.EventHelper

  @topics ~w[receipt replay reply]

  @init_topics for topic <- @topics, reduce: %{}, do: (values -> Map.put(values, topic, 0))

  # %{"/receipt" => :mbx_receipt, "/replay" => :mbx_replay, "/reply" => :mbx_reply}
  @types_mapping (for topic <- @topics, reduce: %{} do
                    types -> Map.put(types, "/" <> topic, String.to_atom("mbx_" <> topic))
                  end)

  Enum.each(@types_mapping, fn {k, v} ->
    def type_to_topic(unquote(k)), do: unquote(v)
  end)

  def register_topics() do
    for {_k, v} <- @types_mapping do
      EventBus.register_topic(v)
    end
  end

  def get_init_topics(), do: @init_topics

  def mailbox_chunk_handler(
        <<"B", _wp_rest::binary-size(43)>> = witness_pre,
        <<"E", _cp_rest::binary-size(43)>> = ctrl_pre
      ) do
    fn chunk ->
      # TODO(VS): add error handling
      {:ok, {events, _unparsed}} = ServerSideEvents.parse_all(chunk)

      # ts = WitnessMailbox.Poller.topics_state(witness_pre, ctrl_pre)

      ts =
        Enum.reduce(
          events,
          %{},
          fn
            %ServerSideEvent{id: id, type: type, data: [data]}, counts
            when id != nil and type != nil ->
              params = %{
                # id: Nanoid.generate(),
                topic: type_to_topic(type)
              }

              EventHelper.notify params do
                {witness_pre, data}
              end

              {idx, ""} = id |> Integer.parse()
              update_topics_idx(counts, type, idx)

            _SSE_event, counts ->
              counts
          end
        )

      WitnessMailbox.TopicsStore.update_counts({witness_pre, ctrl_pre}, ts)

      :ok
    end
  end

  def update_topics_idx(counts, <<"/", topic::bitstring>>, idx) do
    Map.update(counts, topic, idx, fn prev_val -> if(prev_val > idx, do: prev_val, else: idx) end)
  end
end

defmodule WitnessMailbox.Poller do
  @moduledoc """
  GenServer that executes polling requests for mailboxes.

  Each mailbox is identified by a tuple of {wit_pre, ctrl_pref}.

  `Poller` persistently maintains the current state of each mailbox, i.e. it tracks topics and their most recent sn.
  """
  use GenServer

  require Logger
  alias Watcher.WitnessTalker
  alias Kerilex.Event.Query

  def start_link(opts) when is_list(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def init(opts \\ []) do
    timeout = Keyword.get(opts, :timeout, 30_000)
    state = %{timeout: timeout, polls: %{}}

    WitnessMailbox.TopicsStore.check_readiness()
    |> case do
      :ok ->
        {:ok, state}

      {:error, _} = err ->
        err
    end

  end

  def poll(ctrl, talker, stream) do
    if(polling?(talker.wit_pre, ctrl.pre), do: :ok, else: call_poll(ctrl, talker, stream))
  end

  defp call_poll(ctrl, talker, stream) do
    st = next_topics(talker.wit_pre, ctrl.pre)
    {:ok, mbx_qry} = Query.mbx(ctrl.pre, talker.wit_pre, st)
    {:ok, mbx_qry_att} = Query.sign_and_encode_to_cesr(ctrl.pre, [ctrl.signer], mbx_qry)

    GenServer.call(
      __MODULE__,
      {:poll, talker, {talker.wit_pre, ctrl.pre}, {mbx_qry, mbx_qry_att}, stream}
    )
  end

  def polling?(wit_pre, ctrl_pre) do
    GenServer.call(__MODULE__, {:is_polling, {wit_pre, ctrl_pre}})
  end

  def next_topics(wit_pre, ctrl_pre) do
    WitnessMailbox.TopicsStore.get_counts({wit_pre, ctrl_pre})
    |> case do
      :not_found ->
        WitnessMailbox.EventProcessor.get_init_topics()

      {:ok, counts} ->
        counts
        |> inc_topics()
    end
  end

  # def topics_state(wit_pre, ctrl_pre)
  # def update_topics_state(witness_pre, ctrl_pre, ts) do
  #     GenServer.call(__MODULE__, {:new_topics_state, {witness_pre, ctrl_pre}, ts})
  #   end

  #####################  GenServer Handlers ######################
  def handle_call({:is_polling, target}, _from, state) do
    polling? = state |> check_polls(target)
    {:reply, polling?, state}
  end

  # def handle_call({:next_topics, target}, _from, state) do
  #   res =
  #     WitnessMailbox.TopicsStore.get_counts(target)
  #     |> case do
  #       :not_found ->
  #         WitnessMailbox.EventProcessor.get_init_topics()

  #       {:ok, counts} ->
  #         counts
  #         |> inc_topics()
  #     end

  #   {:reply, res, state}
  # end

  def handle_call(
        {:poll, talker, {wit_pre, ctrl_pre} = target, {mbx_qry, mbx_qry_att} = _qry, _stream},
        _from,
        state
      ) do
    chunk_handler = WitnessMailbox.EventProcessor.mailbox_chunk_handler(wit_pre, ctrl_pre)
    timeout = state.timeout

    poll_task = fn ->
      talker
      |> WitnessTalker.poll_mbx!(mbx_qry, mbx_qry_att,
        chunk_handler: chunk_handler,
        timeout: timeout
      )
      |> case do
        {:ok, _} ->
          Logger.debug("[Poller] [poll_task(#{inspect(self())})] finished.")

        {:error, exception} ->
          Logger.debug("[Poller] [poll_task(#{inspect(self())})] error: '#{inspect(exception)}'")
      end

      signal_poll_done(target)
    end

    {:ok, pid} = Task.start(poll_task)
    Logger.debug("[Poller] [poll] started polling worker(#{inspect(pid)})")
    state = state |> update_polls(target, true)
    {:reply, :ok, state}
  end

  # def handle_call({:new_topics_state, target, counts}, _from, state) do
  #   res = WitnessMailbox.TopicsStore.update_counts(target, counts)
  #   Logger.debug("[Poller] new counts for '#{inspect(target)}', counts: '#{inspect(counts)}' ")
  #   {:reply, res, state}
  # end

  defp inc_topics(topics) do
    for {t, v} <- topics, reduce: %{}, do: (next_topics -> Map.put(next_topics, t, v + 1))
  end

  defp update_polls(state, target, running?) do
    Map.update!(state, :polls, &Map.put(&1, target, running?))
  end

  defp check_polls(state, target) do
    Map.get(state.polls, target, false)
  end

  defp signal_poll_done(target), do: GenServer.cast(__MODULE__, {:poll_done, target})

  def handle_cast({:poll_done, target}, state) do
    state = state |> update_polls(target, false)

    Logger.debug(
      "[Poller] poll done for: '#{inspect(target)}', current polls: '#{inspect(state.polls)}'"
    )

    {:noreply, state}
  end
end

defmodule WitnessMailbox.TopicsStore do
  @table :mailbox_topics

  def check_readiness() do
    nodes = :mnesia.system_info(:running_db_nodes)
    tables = :mnesia.system_info(:tables)

    cond do
      nodes == [] ->
        {:error, "mnesia is not started"}

      @table not in tables ->
        {:error, "table #{inspect(@table)} has not been created"}

      true ->
        :mnesia.wait_for_tables([@table], 2000)
        |> case do
          {:timeout, tables} ->
            {:error, "timeout loading tables: '#{inspect(tables)}'"}

          {:error, reason} ->
            {:error, "error loading table '#{inspect(@table)}': '#{inspect(reason)}'"}

          res ->
            res
        end
    end
  end

  def init(nodes \\ [node()]) do
    :mnesia.create_table(@table, disc_copies: nodes, type: :set, attributes: ~w[target topics]a)
    |> case do
      {:atomic, _} ->
        :ok

      {:aborted, reason} ->
        {:error, "failed to created table '#{inspect(@table)}', reason: '#{inspect(reason)}'"}
    end
  end

  def get_counts(target) do
    :mnesia.dirty_read(@table, target)
    |> case do
      [{_table, _target, counts}] -> {:ok, counts}
      [] -> :not_found
    end
  end

  def update_counts(target, counts) do
    updater = fn ->
      old_counts =
        :mnesia.read({@table, target})
        |> case do
          [{_table, _target, old_counts}] ->
            old_counts

          [] ->
            WitnessMailbox.EventProcessor.get_init_topics()
        end

      counts = Map.merge(old_counts, counts)
      :mnesia.write({@table, target, counts})
    end

    :mnesia.transaction(updater)
    |> case do
      {:aborted, reason} ->
        {:error, "failed to update topics' counts: '#{inspect(reason)}'"}

      {:atomic, _} ->
        :ok
    end
  end
end

defmodule Events.TestSubscriber do
  require Logger
  use GenServer

  def start_link(_) do
    GenServer.start_link(__MODULE__, nil, name: __MODULE__)
  end

  def init(_), do: {:ok, %{}}

  def process(event_shadow) do
    GenServer.cast(__MODULE__, event_shadow)
    :ok
  end

  def handle_cast({topic, id} = event_shadow, state) do
    data = EventBus.fetch_event_data(event_shadow)

    Logger.debug(
      "[TEST LOGGER} detected event: {#{inspect(topic)},#{inspect(id)}}, data: '#{inspect(data)}'"
    )

    EventBus.mark_as_skipped({__MODULE__, topic, id})
    {:noreply, state}
  end
end

defmodule Watcher.TestApp do

  def start() do
    WitnessMailbox.EventProcessor.register_topics()
    EventBus.subscribe({Events.TestSubscriber, [".*"]})

    children = [
      {Events.TestSubscriber, 0},
      {WitnessMailbox.Poller, []},
      Watcher.WitnessTalker.child_spec()
    ]

    Supervisor.start_link(children, strategy: :one_for_one)
  end
end
