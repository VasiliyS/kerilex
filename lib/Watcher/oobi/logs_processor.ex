defmodule Watcher.OOBI.LogsProcessor do
  @moduledoc """
  Defines functions to process `KEL`s returned by querying `OOBI`s endpoints of a prefix

  Updates persistent KEL
  """
  alias Watcher.KeyStateEvent
  alias Kerilex.Crypto.KeyTally
  alias Kerilex.KELParser
  alias Kerilex.Event

  alias Watcher.EventEscrow
  alias Watcher.KeyState.Endpoint
  alias Watcher.KeyStateStore
  alias Watcher.KeyState
  alias Watcher.KeyState.{IcpEvent, RotEvent, DipEvent, IxnEvent, DrtEvent}
  alias Watcher.KeyStateCache

  require Logger

  @doc """
  Takes output of `Kerilex.KELParser.parse/1`, verifies each entry and updates the `KeyState` accordingly.
  returns either {:ok, escrow, key_state_cache}, {:duplicity, {pref, sn, stored_event}, serialized_duplicate_event } or an {:error, reason}
  """
  def process_kel(parsed_kel, escrow) when is_list(parsed_kel) do
    parsed_kel
    |> Enum.reduce_while(
      {escrow, KeyStateCache.new()},
      fn msg, {escrow, key_state} ->
        case process_kel_msg(msg, escrow, key_state) do
          {:ok, escrow, key_state} ->
            {:cont, {escrow, key_state}}

          {:out_of_order, said, event_obj} ->
            {:ok, escrow} = escrow |> EventEscrow.add_event(said, event_obj)
            {:cont, {escrow, key_state}}

          {:error, reason} ->
            Logger.debug(%{msg: "failed to process KEL message", error: reason})
            {:halt, {:error, "failed to process a KEL message: " <> reason}}

          {:duplicity, pref, sn, new_event, stored_event} ->
            Logger.debug(%{
              msg: "failed to process KEL message",
              error:
                "potential duplicity detected, pref='#{pref} sn='#{sn}' new event='#{new_event["t"]}' stored event='#{stored_event["t"]}'"
            })

            {:halt, {:duplicity, {pref, sn, stored_event}, Map.fetch!(msg, :serd_msg)}}
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

  @doc """
  Takes one entry from `Kerilex.KELParser.parse/1` output, performs various integrity checks on it
  and updates the persistent KEL.
  Upon success, an updated key state will be returned, if the processed message is an establishment event.
  Also, the escrow will be checked for the waiting events and all events that can be added to the KEL, will be stored.

  Returns `{:ok, escrow, key_state}` , `{:error, reason}`, `{:out_of_order, said, event_obj}`.
  """
  def process_kel_msg(%{} = parsed_msg_map, escrow, state_cache) do
    with {:ok, msg_obj} <- KELParser.check_msg_integrity(parsed_msg_map),
         :ok <- msg_obj |> Event.check_labels(),
         {:ok, said, state, res} <-
           maybe_update_kel(msg_obj["t"], msg_obj, parsed_msg_map, state_cache) do
      Logger.debug(Map.put(res, :msg, "added event"))

      escrow |> process_escrow(said, state)
    end
  end

  @spec maybe_update_kel(nonempty_binary(), Jason.OrderedObject.t(), map(), KeyStateCache.t()) ::
          {:ok, String.t(), KeyStateCache.t(), map()}
          | {:out_of_order, String.t(), map()}
          | {:error, String.t()}
          | {:duplicity, String.t(), String.t()}
  defp maybe_update_kel(event_type, msg_obj, parsed_msg, state_cache)

  defp maybe_update_kel("ixn", msg_obj, parsed_msg, state_cache) do
    with {:ok, ixn_event} <- IxnEvent.from_ordered_object(msg_obj),
         pref = ixn_event["i"],
         curr_key_state <- state_cache |> KeyStateCache.get_key_state(pref),
         :ok <- check_key_state_found(curr_key_state, pref, "ixn", ixn_event["d"]),
         :ok <- IxnEvent.check_sigs(parsed_msg, curr_key_state) do
      KeyStateStore.maybe_update_kel({pref, ixn_event["s"]}, ixn_event)
      |> handle_update_kel_res(ixn_event, state_cache)
    end
  end

  defp maybe_update_kel("rpy", msg_obj, parsed_msg, state_cache) do
    with true <- msg_obj["r"] == "/loc/scheme",
         :ok <- KELParser.check_sigs_on_stateful_msg(msg_obj, parsed_msg),
         {:ok, endpoint} <- Endpoint.new(msg_obj) do
      {msg_obj["a"]["eid"], msg_obj["a"]["scheme"]}
      |> KeyStateStore.maybe_update_backers(endpoint)
      |> handle_update_backers_res(msg_obj, state_cache)
    else
      false ->
        {:ok, "", state_cache,
         %{result: "ignored", reason: "unsupported reply route: `#{msg_obj["r"]}`"}}

      {:error, _} = err ->
        err
    end
  end

  defp maybe_update_kel("icp", msg_obj, parsed_msg, state_cache) do
    with {:ok, sig_th} <- KELParser.check_sigs_on_stateful_msg(msg_obj, parsed_msg),
         {:ok, icp_event} <- IcpEvent.from_ordered_object(msg_obj),
         {:ok, key_state} <- KeyState.new(icp_event, sig_th, parsed_msg, KeyState.new()) do
      state_cache = state_cache |> KeyStateCache.put_key_state(msg_obj["i"], key_state)

      {icp_event["i"], 0}
      |> KeyStateStore.maybe_update_kel(icp_event)
      |> handle_update_kel_res(icp_event, state_cache)
    end
  end

  defp maybe_update_kel("dip", msg_obj, parsed_msg, state_cache) do
    with {:ok, sig_th} <- KELParser.check_sigs_on_stateful_msg(msg_obj, parsed_msg),
         {:ok, dip_event} <- DipEvent.from_ordered_object(msg_obj),
         {:ok, key_state} <- KeyState.new(dip_event, sig_th, parsed_msg, KeyState.new()),
         {:ok, [ssc]} <- KELParser.get_source_seal_couples(parsed_msg),
         :ok <- KeyStateStore.check_seal(dip_event["di"], ssc, KeyStateEvent.seal(dip_event)) do
      state_cache = state_cache |> KeyStateCache.put_key_state(msg_obj["i"], key_state)

      {dip_event["i"], 0}
      |> KeyStateStore.maybe_update_kel(dip_event)
      |> handle_update_kel_res(dip_event, state_cache)
    end
  end

  defp maybe_update_kel("drt", msg_obj, parsed_msg, state_cache) do
    with {:ok, drt_event} <-
           DrtEvent.from_ordered_object(msg_obj),
         {:ok, di} <- fetch_key_from_state_cache(state_cache, drt_event["i"], :di),
         {:ok, [ssc]} <- KELParser.get_source_seal_couples(parsed_msg),
         :ok <- KeyStateStore.check_seal(di, ssc, KeyStateEvent.seal(drt_event)) do
      do_rot_event_update_kel(drt_event, parsed_msg, state_cache)
    else
      {:event_not_found, ssc} ->
        {:error, "anchoring event not found, seal source couple='#{inspect(ssc)}'"}

      err ->
        err
    end
  end

  defp maybe_update_kel("rot", msg_obj, parsed_msg, state_cache) do
    case RotEvent.from_ordered_object(msg_obj) do
      {:ok, rot_event} ->
        do_rot_event_update_kel(rot_event, parsed_msg, state_cache)
    end
  end

  defp maybe_update_kel(type, msg_obj, _parsed_msg, state_cache) do
    {:ok, msg_obj["d"], state_cache,
     %{result: "ignored", reason: "unsupported message type: '#{type}'"}}
  end

  @compile {:inline, do_rot_event_update_kel: 3}
  defp do_rot_event_update_kel(rot_event, parsed_msg, state_cache) do
    with {:ok, sig_th} <- KeyTally.new(rot_event["kt"]),
         pref = rot_event["i"],
         prev_state = state_cache |> KeyStateCache.get_key_state(pref),
         :ok <-
           check_key_state_found(prev_state, pref, rot_event["t"], rot_event["d"]),
         {:ok, key_state} <- KeyState.new(rot_event, sig_th, parsed_msg, prev_state),
         :ok <- KELParser.check_sigs_on_rot_msg(rot_event, key_state.b, parsed_msg) do
      state_cache = state_cache |> KeyStateCache.put_key_state(pref, key_state)

      {pref, rot_event["s"]}
      |> KeyStateStore.maybe_update_kel(rot_event)
      |> handle_update_kel_res(rot_event, state_cache)
    end
  end

  @compile {:inline, check_key_state_found: 4}
  defp check_key_state_found(ks, pref, type, said) when ks == nil do
    {:error, "no intermediate key state found, pref ='#{pref}' type='#{type}' said='#{said}'"}
  end

  defp check_key_state_found(_ks, _pref, _type, _said), do: :ok

  @compile {:inline, fetch_key_from_state_cache: 3}
  defp fetch_key_from_state_cache(ksc, pref, key) do
    case KeyStateCache.get_key_state(ksc, pref) do
      ks when ks != nil ->
        {:ok, Map.fetch!(ks, key)}

      _ ->
        {:error, "no intermediate key state found, pref ='#{pref}'"}
    end
  rescue
    _ ->
      {:error, "requested key('#{inspect({key})}' is not in the key state.)"}
  end

  defp handle_update_backers_res(res, msg_obj, state_cache) do
    case res do
      :ok ->
        {:ok, msg_obj["d"], state_cache,
         %{type: "rpy", result: "added witness", url: msg_obj["a"]["url"]}}

      :not_updated ->
        {:ok, "", state_cache, %{type: "rpy", result: "ignored", reason: "already exists"}}

      error ->
        error
    end
  end

  @compile {:inline, handle_update_kel_res: 3}
  defp handle_update_kel_res(res, event_obj, state_cache) do
    type = event_obj["t"]

    case res do
      {:ok, said} ->
        {:ok, said, state_cache,
         %{type: type, result: "updated KEL", pre: event_obj["i"], sn: event_obj["s"]}}

      :not_updated ->
        {:ok, "", state_cache,
         %{
           type: type,
           result: "ignored",
           reason: "already exists",
           pre: event_obj["i"],
           sn: event_obj["s"]
         }}

      {:out_of_order, said} ->
        {:out_of_order, said, event_obj}

      {:duplicity, _pref, _sn, _event, _stored_event} = dup ->
        # {:error,
        #  "duplicate event detected, already have event '#{type_stored_event}' at sn #{event_obj["s"]}, 'd' is '#{said_stored_event}'"}
        dup

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
