defmodule Watcher.OOBI.LogsProcessor do
  @moduledoc """
  Defines functions to process `KEL`s returned by querying `OOBI`s endpoints of a prefix

  Updates persistent KEL
  """
  alias Kerilex.Crypto.KeyTally
  alias Watcher.KeyState
  alias Watcher.EventEscrow
  require Logger

  @doc """
  Takes output of `Kerilex.KELParser.parse/1`, verifies each entry and updates the `KeyState` accordingly.
  returns either {:ok, escrow, key_state} or an error
  """
  def process_kel(parsed_kel, escrow) when is_list(parsed_kel) do
    parsed_kel
    |> Enum.reduce_while(
      {escrow, KeyState.new()},
      fn msg, {escrow, key_state} ->
        case process_kel_msg(msg, escrow, key_state) do
          {:ok, escrow, key_state} ->
            {:cont, {escrow, key_state}}

          {:out_of_order, said, event_obj} ->
            {:ok, escrow} = escrow |> EventEscrow.add_event(said, event_obj)
            {:cont, {escrow, key_state}}

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
      {:error, _reason} = error ->
        error

      {escrow, key_state} ->
        Logger.info(%{msg: "finished processing KEL messages", kel_length: length(parsed_kel)})
        {:ok, escrow, key_state}
    end
  end

  defp process_escrow(escrow, _said, state) do
    # TODO(VS): implement escrow handling logic
    {:ok, escrow, state}
  end

  alias Kerilex.KELParser
  alias Kerilex.Event

  @doc """
  Takes one entry from `Kerilex.KELParser.parse/1` output, performs various integrity checks on it
  and updates the persistent KEL.
  Upon success, an updated key state will be returned, if the processed message is an establishment event.
  Also, the escrow will be checked for the waiting events and all events that can be added to the KEL, will be stored.

  Returns `{:ok, escrow, key_state}` , `{:error, reason}`, `{:out_of_order, said, event_obj}`.
  """
  def process_kel_msg(%{} = parsed_msg_map, escrow, state) do
    with {:ok, msg_obj} <- KELParser.check_msg_integrity(parsed_msg_map),
         :ok <- msg_obj |> Event.check_labels(),
         {:ok, said, state, res} <- maybe_update_kel(msg_obj["t"], msg_obj, parsed_msg_map, state) do
      Logger.debug(Map.put(res, :msg, "added event"))

      escrow |> process_escrow(said, state)
    end
  end

  alias Watcher.KeyState.Endpoint
  alias Watcher.KeyStateStore

  defp maybe_update_kel("rpy", msg_obj, parsed_msg, _prev_state) do
    with true <- msg_obj["r"] == "/loc/scheme",
         :ok <- KELParser.check_sigs_on_stateful_msg(msg_obj, parsed_msg),
         {:ok, endpoint} <- Endpoint.new(msg_obj) do
      {msg_obj["a"]["eid"], msg_obj["a"]["scheme"]}
      |> KeyStateStore.maybe_update_backers(endpoint)
      |> handle_update_backers_res(msg_obj)
    else
      false ->
        {:ok, "", %{result: "ignored", reason: "unsupported reply route: `#{msg_obj["r"]}`"}}

      {:error, _} = err ->
        err
    end
  end

  alias Watcher.KeyState
  alias Watcher.KeyState.{IcpEvent, RotEvent}

  defp maybe_update_kel("icp", msg_obj, parsed_msg, _prev_state) do
    with {:ok, sig_th} <- KELParser.check_sigs_on_stateful_msg(msg_obj, parsed_msg),
         {:ok, icp_event} <- IcpEvent.from_ordered_object(msg_obj),
         {:ok, key_state} <- KeyState.new(icp_event, sig_th, parsed_msg, KeyState.new()) do
      {icp_event["i"], 0}
      |> KeyStateStore.maybe_update_kel(icp_event)
      |> handle_update_kel_res(icp_event, key_state)
    end
  end

  defp maybe_update_kel("rot", msg_obj, parsed_msg, prev_state) do
    with {:ok, rot_event} <- RotEvent.from_ordered_object(msg_obj),
        {:ok, sig_th} <- KeyTally.new(rot_event["kt"]),
         {:ok, key_state} <- KeyState.new(rot_event, sig_th, parsed_msg, prev_state),
         :ok <- KELParser.check_sigs_on_rot_msg(msg_obj, key_state.b, parsed_msg) do
      {rot_event["i"], rot_event["s"]}
      |> KeyStateStore.maybe_update_kel(rot_event)
      |> handle_update_kel_res(rot_event, key_state)
    end
  end

  defp maybe_update_kel(type, msg_obj, _parsed_msg, _prev_state) do
    {:ok, msg_obj["d"], %{result: "ignored", reason: "unsupported message type: '#{type}'"}}
  end

  defp handle_update_backers_res(res, msg_obj) do
    case res do
      :ok ->
        {:ok, msg_obj["d"], %{type: "rpy", result: "added witness", url: msg_obj["a"]["url"]}}

      :not_updated ->
        {:ok, "", %{type: "rpy", result: "ignored", reason: "already exists"}}

      error ->
        error
    end
  end

  defp handle_update_kel_res(res, event_obj, new_ks) do
    type = event_obj["t"]

    case res do
      {:ok, said} ->
        {:ok, said, new_ks,
         %{type: type, result: "updated KEL", pre: event_obj["i"], sn: event_obj["s"]}}

      :not_updated ->
        {:ok, "", new_ks,
         %{
           type: type,
           result: "ignored",
           reason: "already exists",
           pre: event_obj["i"],
           sn: event_obj["s"]
         }}

      {:out_of_order, said} ->
        {:out_of_order, said, event_obj}

      {:duplicate, type_stored_event, said_stored_event} ->
        {:error,
         "duplicate event detected, already have event '#{type_stored_event}' at sn #{event_obj["s"]}, 'd' is '#{said_stored_event}'"}

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
