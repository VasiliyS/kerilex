defmodule Watcher.AIDMonitor.KeyStateUpdater.Pool do
  alias Watcher.AIDMonitor.KeyStateUpdater.Worker
  @pool_id :key_state_updater_worker_pool

  def child_spec(_opts) do
    Poolex.child_spec(
      pool_id: @pool_id,
      worker_module: Worker,
      workers_count: worker_count(),
      max_overflow: max_overflow()
    )
  end

  defp worker_count do
    System.schedulers_online() |> div(2)
  end

  defp max_overflow do
    System.schedulers_online() |> div(2)
  end

  def pool_id, do: @pool_id
end

defmodule Watcher.AIDMonitor.KeyStateUpdater.Worker do
  @moduledoc """
  Worker process that updates key sate
  """

  use GenServer
  require Logger

  alias Watcher.KeyStateCache
  alias Kerilex.KELParser
  alias Watcher.{OOBI.LogsProcessor, KeyStateStore, EventEscrow}
  alias Watcher.AIDMonitor.KeyStateUpdater.Pool

  @pool_id Pool.pool_id()
  @check_out_timeout 2000

  def start_link do
    GenServer.start_link(__MODULE__, :ok)
  end

  @doc """
  performs an incremental update of the AID's key state based on the provided KEL events
  """
  @spec process_new_events(list(KELParser.parsed_kel_element()), Kerilex.pre()) ::
          :ok | {:error, :checkout_timeout}
  def process_new_events(events, aid) do
    Poolex.run(
      @pool_id,
      fn pid ->
        GenServer.call(pid, {:process_new_events, events, aid})
      end,
      checkout_timeout: @check_out_timeout
    )
    |> case do
      {:ok, _} ->
        :ok

      err ->
        err
    end
  end

  @impl true
  def init(:ok) do
    {:ok, nil}
  end

  @impl true
  def handle_call({:process_new_events, parsed_events, aid}, _from, state) do
    escrow = EventEscrow.new()

    with {:ok, states} <- KeyStateStore.collect_key_state(aid),
         {:ok, escrow, ksc, cnt} <-
           LogsProcessor.process_kel(parsed_events, escrow, key_states: states),
         :ok <- KeyStateStore.maybe_update_key_states(ksc, ignore_shorter_kels: true) do
      if !EventEscrow.empty?(escrow) do
        Logger.warning(%{msg: "KEL has out of order events"})
      end

      if KeyStateCache.has_recoveries?(ksc) do
        Logger.warning(%{
          msg: "performed superseding recovery",
          aid_sn_pairs: inspect(KeyStateCache.get_recoveries(ksc))
        })
      end

      Logger.info(%{msg: "updated key state", processed_key_events: cnt})
    else
      error ->
        handle_errors(error, aid)
    end

    {:reply, :ok, state}
  end

  defp handle_errors(error, aid) do
    case error do
      :not_found ->
        Logger.error(%{msg: "no key state found in the store", aid: aid})

      {:error, reason} ->
        Logger.error(%{msg: "failed to process new key events", error: reason})

      {:duplicity, {pre, sn, stored_event}, dup_event} ->
        Logger.error(%{
          msg: "duplicity detected",
          aid_prefix: pre,
          at_sn: sn,
          event_d: stored_event["d"],
          event_t: stored_event["t"],
          dup_event: dup_event
        })
    end
  end
end
