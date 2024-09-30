defmodule Watcher.AIDMonitor.WorkerLib do
  alias Watcher.KeyStateStore
  import Kerilex.Helpers, only: [hex_to_int: 2]

  @spec filter_stored_events(Kerilex.kel_ilk(), Kerilex.said(), Kerilex.pre(), Kerilex.hex_sn()) ::
          :cont | :skip | {:halt, {:error, String.t()}}
  def filter_stored_events(type, said, pre, sn_hex)

  def filter_stored_events(_type, _said, "", "") do
    :cont
  end

  def filter_stored_events(_type, said, pre, sn_hex) do
    with {:ok, sn} <-
           hex_to_int(sn_hex, "'s' field is badly formatted") do
      check_in_store(pre, sn, said)
    else
      err ->
        {:halt, err}
    end
  end

  defp check_in_store(pre, sn, said) do
    case KeyStateStore.has_event?(pre, sn, said) do
      true ->
        :skip

      false ->
        :cont

      err ->
        {:halt, err}
    end
  end
end

defmodule Watcher.AIDMonitor.KeyStateObserver.Worker do
  require Logger
  use Task

  alias Watcher.AIDMonitor.KeyStateUpdater.Worker, as: KeyStateUpdater
  alias Watcher.OOBI.{Resolver}
  alias Watcher.{AIDMonitor.WorkerLib}
  alias Kerilex.KELParser


  def start_link(aid) do
    Task.start_link(__MODULE__, :get_and_process_logs, [aid])
  end

  def get_and_process_logs({_timestamp, aid}) do
    Process.set_label(__MODULE__)
    # Logger.debug(%{msg: "processing observation...", observation: observation})
    case Resolver.get_logs(aid) do
      {:ok, kel} ->
        process_logs(aid, kel)

      :skip ->
        Logger.info(%{msg: "skipping updating key state", reason: "could not get logs", aid: aid})

      {:error, log_report} ->
        Logger.error(Map.merge(%{msg: "can not update update key state"}, log_report))
    end
  end

  defp process_logs(aid, kel) do
    kel
    |> KELParser.parse(filter_fn: &WorkerLib.filter_stored_events/4)
    |> maybe_update_key_state_store(aid)
  end

  defp maybe_update_key_state_store({:error, reason}, _aid) do
    Logger.error(%{msg: "failed to parse KEL", error: reason})
  end

  defp maybe_update_key_state_store([], aid) do
    Logger.info(%{msg: "no new events in the received KEL", aid: aid})
  end

  defp maybe_update_key_state_store(new_parsed_events, aid) do
    KeyStateUpdater.process_new_events(new_parsed_events, aid)
    |> case do
      :ok ->
        Logger.info(%{msg: "updated state for AID prefix='#{aid}'"})

      {:error, :checkout_timeout} ->
        Logger.debug(%{
          msg: "failed to update key state for AID prefix='#{aid}', no free workers available"
        })
    end
  end
end
