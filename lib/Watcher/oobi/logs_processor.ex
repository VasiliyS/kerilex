defmodule Watcher.OOBI.LogsProcessor do
  @moduledoc """
  Defines functions to process `KEL`s returned by querying `OOBI`s endpoints of a prefix

  Updates persistent state.
  """
  require Logger

  @doc """
  Takes output of `Kerilex.KELParser.parse/1`, verifies each entry and updates the `KeyState` accordingly.
  """
  def process_kel(parsed_kel) when is_list(parsed_kel) do
    parsed_kel
    |> Enum.reduce_while(
      nil,
      fn msg, _acc ->
        case process_kel_msg(msg) do
          {:ok, msg_info} ->
            Logger.debug(Map.merge(%{msg: "processed KEL message"}, msg_info))
            {:cont, :ok}

          {:error, reason} = err ->
            Logger.debug(%{msg: "failed to process KEL message", error: reason})
            {:halt, err}

          {:duplicity, said} ->
            Logger.debug(%{
              msg: "failed to process KEL message",
              error: "potential duplicity detected"
            })

            {:halt, {:duplicity, said, Map.fetch!(msg, :serd_msg)}}
        end
      end
    )
    |> case do
      :ok ->
        Logger.info(%{msg: "finished processing KEL messages", kel_length: length(parsed_kel)})
        :ok

      error ->
        error
    end
  end

  alias Kerilex.KELParser
  alias Kerilex.Event

  @doc """
  Takes one entry from `Kerilex.KELParser.parse/1` output and updates the state.

  Returns `{:ok, msg_info}` or `{:error, reason}`. `msg_info` is a map with results of the message processing.
  """
  def process_kel_msg(%{} = parsed_msg_map) do
    with {:ok, msg_obj} <- KELParser.check_msg_integrity(parsed_msg_map),
         :ok <- msg_obj |> Event.check_labels() do
      maybe_update_state(msg_obj["t"], msg_obj, parsed_msg_map)
    end
  end

  alias Watcher.KeyState.Endpoint
  alias Watcher.KeyStateStore

  defp maybe_update_state("rpy", msg_obj, parsed_msg) do
    with true <- msg_obj["r"] == "/loc/scheme",
         :ok <- KELParser.check_sigs_on_stateful_msg(msg_obj, parsed_msg),
         {:ok, endpoint} <- Endpoint.new(msg_obj) do
      {msg_obj["a"]["eid"], msg_obj["a"]["scheme"]}
      |> KeyStateStore.maybe_update_backers(endpoint)
      |> handle_update_backers_res(msg_obj)
    else
      false ->
        {:ok, %{result: "ignored", reason: "unsupported reply route: `#{msg_obj["r"]}`"}}

      {:error, _} = err ->
        err
    end
  end

  alias Watcher.KeyState.IcpEvent

  defp maybe_update_state("icp", msg_obj, parsed_msg) do
    with :ok <- KELParser.check_sigs_on_stateful_msg(msg_obj, parsed_msg),
         {:ok, icp_event} <- IcpEvent.from_ordered_object(msg_obj),
         {pre, sn} = key <- {icp_event["i"], 0},
         {:ok, res} <-
           KeyStateStore.maybe_update_kel(key, icp_event)
           |> handle_update_kel_res(icp_event) do
      Logger.debug(Map.put(res, :msg, "added establishment event"))

      KeyStateStore.maybe_update_ks(pre, sn, icp_event)
      |> handle_update_ks_res(icp_event)
    else
      {:duplicate, type_stored_event, said_stored_event} ->
        {:error,
         "duplicate icp event detected, already have event '#{type_stored_event}' at sn 0, 'd' is '#{said_stored_event}'"}

      error ->
        error
    end
  end

  defp maybe_update_state(type, _msg_obj, _parsed_msg) do
    {:ok, %{result: "ignored", reason: "unsupported message type: '#{type}'"}}
  end

  defp handle_update_backers_res(res, msg_obj) do
    case res do
      :ok ->
        {:ok, %{type: "rpy", result: "added witness", url: msg_obj["a"]["url"]}}

      :not_updated ->
        {:ok, %{type: "rpy", result: "ignored", reason: "already exists"}}

      error ->
        error
    end
  end

  defp handle_update_kel_res(res, msg_obj) do
    type = msg_obj["t"]

    case res do
      :ok ->
        {:ok, %{type: type, result: "updated KEL", pre: msg_obj["i"], sn: msg_obj["s"]}}

      :not_updated ->
        {:ok,
         %{
           type: type,
           result: "ignored",
           reason: "already exists",
           pre: msg_obj["i"],
           sn: msg_obj["s"]
         }}

      error ->
        error
    end
  end

  defp handle_update_ks_res(res, msg_obj) do
    type = msg_obj["t"]

    case res do
      :ok ->
        {:ok, %{type: type, result: "updated key state", pre: msg_obj["i"], sn: msg_obj["s"]}}

      {:not_updated, stored_sn} ->
        {:ok,
         %{
           type: type,
           result: "ignored",
           reason: "stored state is newer: #{stored_sn}",
           pre: msg_obj["i"],
           sn: msg_obj["s"]
         }}

      error ->
        error
    end
  end
end
