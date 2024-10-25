defmodule Watcher.AIDMonitor.ObservationScheduler.State do
  @moduledoc false
  @type timestamp :: integer()
  @type batch :: {timestamp(), list(Kerilex.pre())}
  @type t :: %__MODULE__{
          queue: :queue.queue(),
          pend_demand: non_neg_integer(),
          one_sec_ticks: non_neg_integer(),
          ref_time_point: timestamp(),
          ready: boolean()
        }
  defstruct queue: :queue.new(),
            pend_demand: 0,
            one_sec_ticks: 0,
            ref_time_point: nil,
            ready: false
end

defmodule Watcher.AIDMonitor.ObservationScheduler do
  use GenStage

  require Logger
  alias Watcher.AIDMonitor.Store, as: MonitorStore
  alias Watcher.AIDMonitor.ObservationScheduler.State, as: SchedulerState

  @one_second_tick :do_observation

  def start_link(_opts) do
    GenStage.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  @impl true
  def init(:ok) do
    {:producer, %SchedulerState{}}
  end

  defp schedule_one_sec_tick() do
    Process.send_after(self(), @one_second_tick, 1000)
  end

  defp scheduling_slots(%SchedulerState{} = state, timestamp) do
    seconds_count = state.one_sec_ticks + 1
    state = %SchedulerState{state | one_sec_ticks: seconds_count}

    if ref_time_point = state.ref_time_point do
      ref_milliseconds =
        :erlang.convert_time_unit(timestamp - ref_time_point, :native, :millisecond)

      # allow up to 500 ms jitter
      ref_seconds = (ref_milliseconds / 1000) |> round()

      # monotonic time can, theoretically, freeze, depending on the `warp mode`
      # see here : https://www.erlang.org/doc/apps/erts/erlang#monotonic_time/0
      if ref_seconds > seconds_count do
        Logger.debug(%{
          msg: "adjusting seconds_count, was: '#{seconds_count}', new: '#{ref_seconds}'"
        })

        {%SchedulerState{state | ref_time_point: timestamp, one_sec_ticks: ref_seconds},
         Range.new(seconds_count, ref_seconds) |> Range.to_list()}
      else
        {state, [seconds_count]}
      end
    else
      {%SchedulerState{state | ref_time_point: timestamp}, [seconds_count]}
    end
  end

  @impl true
  def handle_subscribe(:consumer, opts, from, state) do
    Logger.debug(%{msg: "got subscriber", opts: opts, from: from})

    schedule_one_sec_tick()

    {:automatic, %SchedulerState{state | ready: true}}
  end

  @impl true
  def handle_info(@one_second_tick, %SchedulerState{} = state) do
    timestamp = :erlang.monotonic_time()
    {state, slots} = state |> scheduling_slots(timestamp)

    new_batch = select_observation_batch!(timestamp, slots)
    state = state |> update_queue(new_batch)
    res = dispatch_observations(state, state.pend_demand, _observations = [])
    schedule_one_sec_tick()

    res
  rescue
    e ->
      Logger.error(%{msg: "failed to get observations", error: Exception.message(e)})
      {:noreply, [], state}
  end

  defp select_observation_batch!(timestamp, slots) do
    # Logger.debug(%{msg: "building batch", timestamp: timestamp, slots: slots})
    build_batch!(slots, timestamp, _aids = [])
  end

  defp build_batch!([], timestamp, aids) do
    {timestamp, aids}
  end

  defp build_batch!([slot | slots], timestamp, aids) do
    # Logger.debug(%{msg: "getting observations", slot: slot})

    res =
      case MonitorStore.select_for_observation(slot) do
        {:error, reason} ->
          raise "failed to get observations for slot='#{slot}' seconds, " <> reason

        {:ok, []} ->
          aids

        {:ok, selected_aids} ->
          if [] == aids, do: selected_aids, else: selected_aids ++ aids
      end

    build_batch!(slots, timestamp, res)
  end

  defp update_queue(state, {_timestamp, []}) do
    # Logger.debug(%{msg: "skipping empty batch"})
    state
  end

  defp update_queue(%SchedulerState{queue: queue} = state, batch) do
    Logger.debug(%{msg: "adding batch to queue", queue_len: :queue.len(queue) + 1, batch: batch})
    %SchedulerState{state | queue: :queue.in(batch, queue)}
  end

  @impl true
  def handle_demand(demand, %SchedulerState{pend_demand: pending_demand} = state) do
    Logger.debug(%{msg: "received new demand", demand: demand, pending_demand: pending_demand})
    dispatch_observations(state, pending_demand + demand, [])
  end

  defp dispatch_observations(state, _demand = 0, observations) do
    Logger.debug(%{msg: "satisfied all demand", queue_len: state.queue |> :queue.len() })
    # schedule_one_sec_tick()

    {:noreply, Enum.reverse(observations), %SchedulerState{state | pend_demand: 0}}
  end

  defp dispatch_observations(%SchedulerState{queue: queue} = state, demand, observations) do
    case :queue.peek(queue) do
      {:value, batch} ->
        {rem_demand, observations, queue} =
          queue |> :queue.drop() |> batch_to_observations(observations, batch, demand)

        dispatch_observations(%SchedulerState{state | queue: queue}, rem_demand, observations)

      :empty ->
        # Logger.debug(%{
          # msg: "sending demand, queue is empty",
          # pending_demand: demand,
          # observations: observations
        # })

        {:noreply, Enum.reverse(observations), %SchedulerState{state | pend_demand: demand}}
    end
  end

  defp batch_to_observations(queue, observations, {timestamp, aids} = _batch, demand) do
    {rem_demand, aids_rest, observations} =
      1..demand
      |> Enum.reduce_while(
        {demand, aids, observations},
        fn
          _ind, {rem_demand, [], observations} ->
            {:halt, {rem_demand, [], observations}}

          _ind, {rem_demand, [aid | rest], observations} ->
            {:cont, {rem_demand - 1, rest, [{timestamp, aid} | observations]}}
        end
      )

    {rd, obs, q} = maybe_satisfy_demand(queue, timestamp, rem_demand, aids_rest, observations)
    Logger.debug(%{msg: "built observations from batch", pending_demand: rd})
    {rd, obs, q}
  end

  defp maybe_satisfy_demand(queue, _timestamp, 0 = _rem_demand, [] = _aids_rest, observations) do
    {0, observations, queue}
  end

  defp maybe_satisfy_demand(queue, timestamp, 0 = _rem_demand, aids_rest, observations) do
    # return the non-consumed part of the scheduled aids to the head of the queue
    queue = :queue.in_r({timestamp, aids_rest}, queue)
    {0, observations, queue}
  end

  defp maybe_satisfy_demand(queue, _timestamp, rem_demand, [] = _aids_rest, observations) do
    case :queue.peek(queue) do
      :empty ->
        {rem_demand, observations, queue}

      {:value, prev_batch} ->
        queue = :queue.drop(queue)
        batch_to_observations(queue, observations, prev_batch, rem_demand)
    end
  end
end
