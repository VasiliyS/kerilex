defmodule Watcher.OOBI.LogsProcessorError do
  @moduledoc """
  `LogsProcessorError` exception

  accessible fields:
  - `message` - erorr message
  - `pre` - AID prefix
  - `sn`  - int seq number of the currently processed event
  - `key_state` - `Watcher.KeyState` struct
  """
  defexception ~w[message pre sn key_state]a
end

defmodule Watcher.OOBI.LogsProcessor do
  @moduledoc """
  Defines functions to process `KEL`s returned by querying `OOBI`s endpoints of a prefix

  Updates persistent KEL
  """

  alias Watcher.OOBI.LogsProcessorError
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

  @typedoc """
  map used to log a structured message
  """
  @type log_response :: %{optional(atom()) => any()}

  @doc """
  Takes output of `Kerilex.KELParser.parse/1`, verifies each entry and updates the `KeyState` accordingly.
  returns: todo
  """
  def process_kel(parsed_kel, escrow, opts \\ [])
      when is_list(parsed_kel) and is_list(opts) and is_struct(escrow, EventEscrow) do
    ksc =
      if key_states = opts[:key_states] do
        KeyStateCache.new!(key_states)
      else
        KeyStateCache.new()
      end

    parsed_kel
    |> Enum.reduce_while(
      {escrow, ksc},
      &process_kel_reducer/2
    )
    |> case do
      {:error, _reason} = error ->
        error

      {escrow, key_state} ->
        Logger.debug(%{msg: "finished processing KEL messages", kel_length: length(parsed_kel)})
        {:ok, escrow, key_state}
    end
  end

  defp process_kel_reducer(msg, {escrow, key_state}) do
    case process_kel_msg(msg, key_state) do
      {:ok, said, key_state, res} when said != nil ->
        Logger.debug(Map.put(res, :msg, "added event"))

        escrow
        |> process_escrow(said, key_state)
        |> case do
          {:ok, escrow, key_state} ->
            {:cont, {escrow, key_state}}

          {:error, reason} ->
            do_process_kel_err(reason)
        end

      {:ok, _said = nil, key_state, res} ->
        Logger.debug(Map.put(res, :msg, "event not added"))
        {:cont, {escrow, key_state}}

      {:out_of_order, said, event_obj} ->
        pre = event_obj["i"]

        {:ok, escrow} =
          escrow |> EventEscrow.add_event(said, event_obj, msg)

        Logger.debug(%{
          msg: "added out of order event to escrow",
          waiting_for: said,
          pre: pre,
          type: event_obj["t"],
          sn: event_obj["s"]
        })

        {:cont, {escrow, key_state}}

      {:error, reason} ->
        do_process_kel_err(reason)

      {:duplicity, pref, sn, new_event, stored_event} ->
        Logger.debug(%{
          msg: "failed to process KEL message",
          error:
            "potential duplicity detected, pref='#{pref} sn='#{sn}' new event='#{new_event["t"]}' stored event='#{stored_event["t"]}'"
        })

        {:halt, {:duplicity, {pref, sn, stored_event}, Map.fetch!(msg, :serd_msg)}}

      other ->
        raise "kel processing pipeline returned an unknown response: '#{inspect(other)}'"
    end
  end

  @compile {:inline, do_process_kel_err: 1}
  defp do_process_kel_err(reason) do
    Logger.debug(%{msg: "failed to process KEL message", error: reason})
    {:halt, {:error, "failed to process a KEL message: " <> reason}}
  end

  @spec process_escrow(EventEscrow.t(), Kerilex.said(), KeyStateCache.t()) ::
          {:ok, EventEscrow.t(), KeyStateCache.t()} | {:error, String.t()}
  defp process_escrow(escrow, said_key, state_cache) do
    case EventEscrow.pop_events_waiting_for(escrow, said_key) do
      {:ok, events, escrow} ->
        events
        |> Enum.reduce_while(
          {:ok, escrow, state_cache},
          &escrow_event_reducer(&1, &2, said_key)
        )

      :not_found ->
        {:ok, escrow, state_cache}
    end
  end

  defp escrow_event_reducer({msg_obj, parsed_event}, {:ok, escrow, state_cache}, said_key) do
    Logger.debug(%{
      msg: "processing event from out of order escrow",
      waiting_for: said_key,
      type: msg_obj["t"],
      sn: msg_obj["s"],
      said: msg_obj["d"]
    })

    with {:ok, said, new_state, response} <-
           maybe_update_kel(msg_obj["t"], msg_obj, _found_event = nil, parsed_event, state_cache),
         _ = Logger.debug(Map.put(response, :msg, "added event from escrow")),
         {:ok, escrow, state} <-
           process_escrow(escrow, said, new_state) do
      {:cont, {:ok, escrow, state}}
    else
      error ->
        {:halt, error}
    end
  end

  @spec process_kel_msg(
          map(),
          KeyStateCache.t()
        ) ::
          {:ok, Kerilex.said() | nil, KeyStateCache.t(), log_response()}
          | {:out_of_order, Kerilex.said(), Jason.OrderedObject.t()}
          | {:error, String.t()}
          | {:duplicity, Kerilex.pre(), Kerilex.int_sn(), Jason.OrderedObject.t(),
             KeyStateStore.stored_event()}
  @doc """
  Takes one entry from `Kerilex.KELParser.parse/1` output, performs various integrity checks on it
  and updates the persistent KEL.
  Upon success, an updated key state will be returned, if the processed message is an establishment event.

  Returns todo.
  """
  def process_kel_msg(%{} = parsed_msg_map, state_cache) do
    with {:ok, msg_obj} <- KELParser.check_msg_integrity(parsed_msg_map),
         :ok <- msg_obj |> Event.check_labels() do
      # basic verification is now done
      # process `rpy` message separately
      do_process_msg(msg_obj["t"], msg_obj, parsed_msg_map, state_cache)
    end
  end

  defp do_process_msg(type, msg_obj, parsed_msg_map, state_cache)
       when type in ~w|icp rot ixn dip drt| do
    with {:ok, sn} <-
           Kerilex.Helpers.hex_to_int(msg_obj["s"], "event's `s` field is not properly encoded"),
         msg_obj = update_in(msg_obj["s"], fn _ -> sn end),
         :ok <-
           check_config_and_parent(msg_obj, state_cache) do
      case check_msg_in_state_cache(msg_obj["i"], sn, state_cache) do
        :ok ->
          # at this point we know that this event is allowed and it's parent is already processed
          # and that this event was not processed before
          # we are now ready to store the event in the KEL if signature checks are successful
          maybe_update_kel(type, msg_obj, _found_event = nil, parsed_msg_map, state_cache)

        :maybe_duplicate ->
          try do
            process_maybe_duplicate_msg(type, msg_obj, parsed_msg_map, state_cache)
          catch
            err -> err
          end
      end
    end
  end

  defp do_process_msg("rpy", msg_obj, parsed_msg_map, state_cache) do
    with true <- msg_obj["r"] == "/loc/scheme",
         :ok <- KELParser.check_sigs_on_stateful_msg(msg_obj, parsed_msg_map),
         {:ok, endpoint} <- Endpoint.new(msg_obj) do
      {msg_obj["a"]["eid"], msg_obj["a"]["scheme"]}
      |> KeyStateStore.maybe_update_backers(endpoint)
      |> handle_update_backers_res(msg_obj, state_cache)
    else
      false ->
        {:ok, nil, state_cache,
         %{result: "ignored", reason: "unsupported reply route: `#{msg_obj["r"]}`"}}

      {:error, _} = err ->
        err
    end
  end

  defp do_process_msg(type, msg_obj, _parsed_msg_map, _state_cache) do
    {:error, "unsupported event: type='#{type}' said='#{msg_obj["d"]}'"}
  end

  defp check_msg_in_state_cache(pre, sn, state_cache) do
    case KeyStateCache.get_last_event_for(state_cache, pre) do #|> IO.inspect(label: "last event") do
      {:ok, {_type, le_sn, _said}} ->
        if le_sn > sn - 1, do: :maybe_duplicate, else: :ok

      :not_found ->
        :ok

      {:ok, nil} ->
        # runtime error, either pref is not in cache (nothing has been added yet) or there must be event data
        raise "key state for pre=#{pre} is missing!, checking for existence of event with sn=#{sn}"
    end
  end

  defp process_maybe_duplicate_msg(type, msg_obj, parsed_msg_map, state_cache) do
    pre = msg_obj["i"]
    sn = msg_obj["s"]
    # msg_obj |> IO.inspect(label: "process_maybe_duplicate_event")

    found_event =
      case KeyStateStore.find_event(pre, sn) do #|> IO.inspect(label: "find_event") do
        {:key_event_found, found_event} ->
          found_event

        :key_event_not_found ->
          ks = KeyStateCache.get_key_state(state_cache, pre)

          raise LogsProcessorError,
            message: "no event found in DB when processing duplicate event",
            pre: pre,
            sn: sn,
            key_state: ks

        {:error, _} = err ->
          throw(err)
      end

    cond do
      found_event["d"] == msg_obj["d"] ->
        {:ok, nil, state_cache,
         %{
           type: type,
           result: "ignored",
           reason: "already exists",
           pre: pre,
           sn: sn
         }}

      type in ~w|icp dip ixn| ->
        # these types can't replace previous events
        {:duplicity, pre, sn, msg_obj, :not_checked}

      type in ~w|rot drt| ->
        # `rot` and `drt` can be recovery attempts
        ks = KeyStateCache.get_key_state!(state_cache, pre)

        if (ks.se >= sn and type == "rot") or
             (type == "drt" and (ks.se > sn or (ks.se == sn and ks.te != "drt"))) do
          {:error,
           "kel has an establishment event type='#{ks.te}' at sn='#{ks.se}' after or at the current sn=#{sn}, superseding recovery with '#{type}' is not possible"}
        else
          maybe_do_recovery!(type, msg_obj, parsed_msg_map, state_cache)
        end

      true ->
        {:error,
         "duplicate event has unknown type='#{type} pre='#{pre}' sn=#{sn} said='#{msg_obj["d"]}'"}
    end
  end

  defp maybe_do_recovery!(type, msg_obj, parsed_msg_map, state_cache) do
    pre = msg_obj["i"]
    sn = msg_obj["s"]

    case(KeyStateStore.find_event(pre, sn)) do
      {:key_event_found, found_event} ->
        msg =
          "potential superseding recovery detected, existing event t='#{found_event["t"]}' s='#{found_event["s"]}' said='#{found_event["d"]}'"

        Logger.warning(%{msg: msg, type: type, pre: pre, sn: sn})
        maybe_store_msg(type, found_event["t"], msg_obj, parsed_msg_map, state_cache)

      :key_event_not_found ->
        # we have an incorrect key state!, there must be an event at this key
        ks = KeyStateCache.get_key_state!(state_cache, pre)

        raise LogsProcessorError,
          pre: pre,
          sn: sn,
          key_state: ks,
          message: "failed to retrieve kel event during attempted recovery"
    end
  end

  @compile {:inline, [maybe_update_kel: 5]}
  @spec maybe_update_kel(
          Kerilex.kel_ilk(),
          Jason.OrderedObject.t(),
          map() | nil,
          map(),
          KeyStateCache.t()
        ) ::
          {:ok, Kerilex.said() | nil, KeyStateCache.t(), log_response()}
          | {:out_of_order, Kerilex.said(), Jason.OrderedObject.t()}
          | {:error, String.t()}
          | {:duplicity, Kerilex.pre(), Kerilex.int_sn(), Jason.OrderedObject.t(),
             KeyStateStore.stored_event()}
  defp maybe_update_kel(type, msg_obj, found_event, parsed_msg_map, state_cache)

  defp maybe_update_kel(type, msg_obj, nil = _found_event, parsed_msg_map, state_cache) do
    maybe_store_msg(type, _found_type = nil, msg_obj, parsed_msg_map, state_cache)
  end

  # defp maybe_update_kel(type, msg_obj, found_event, parsed_msg_map, state_cache) do
  #   with :not_duplicate <-
  #          if(msg_obj["d"] != found_event["d"],
  #            do: :not_duplicate,
  #            else: :duplicate
  #          ),
  #        :ok <- check_config_and_parent(msg_obj, state_cache) do
  #     pre = msg_obj["i"]
  #     sn = msg_obj["s"]

  #     if msg_obj["t"] in ~w|icp dip ixn| do
  #       # these types can't replace previous events
  #       {:duplicity, pre, sn, msg_obj, found_event}
  #     else
  #       # `rot` and `drt` can be recovery attempts
  #       msg =
  #         "potential superseding recovery detected, existing event pre='#{found_event["i"]}' t='#{found_event["t"]}' s='#{found_event["s"]}' said='#{found_event["d"]}'"

  #       Logger.warning(%{msg: msg, type: type, pre: pre, sn: sn})
  #       maybe_store_msg(type, found_event["d"], msg_obj, parsed_msg_map, state_cache)
  #     end
  #   else
  #     :duplicate ->
  #       {:ok, nil, state_cache,
  #        %{
  #          type: type,
  #          result: "ignored",
  #          reason: "already exists",
  #          pre: msg_obj["i"],
  #          sn: msg_obj["s"]
  #        }}

  #     err ->
  #       err
  #   end
  # end

  defp check_config_and_parent(msg_obj, state_cache) do
    pref = msg_obj["i"]
    sn = msg_obj["s"]

    with :ok <- if(sn > 0, do: event_allowed?(pref, msg_obj, state_cache), else: :ok),
         :ok <- if(sn > 0, do: check_parent(pref, sn, msg_obj["p"], state_cache), else: :ok) do
      :ok
    else
      :no_icp_event ->
        {:out_of_order, msg_obj["p"], msg_obj}

      {:no_parent_event, msg_said} ->
        {:out_of_order, msg_said, msg_obj}

      {:error, _} = err ->
        err
    end
  end

  defp check_parent(pref, sn, prev_said, state_cache) do
    {_t, le_sn, le_said} = KeyStateCache.fetch_for!(state_cache, pref, :last_event)

    cond do
      le_sn == sn - 1 and prev_said == le_said ->
        :ok

      le_sn == sn - 1 and prev_said != le_said ->
        {:error,
         "event for AID pref='#{pref}' sn='#{sn}' failed parent hash check. 'p'='#{prev_said}', should be '#{le_said}'"}

      le_sn < sn ->
        {:no_parent_event, prev_said}

      true ->
        :ok  # this is likely a duplicate event, will check for recovery and rules later in teh pipeline
    end
  end

  defp event_allowed?(pref, msg_obj, state_cache) do
    case KeyStateCache.get_config_for(state_cache, pref) do
      {:ok, conf} ->
        if Event.is_event_allowed?(conf, msg_obj["t"]) do
          :ok
        else
          {:error,
           "inception config: '#{inspect({conf})}' for pref '#{pref}' disallows adding event type: '#{msg_obj["t"]}'"}
        end

      :not_found ->
        :no_icp_event
    end
  end

  @spec maybe_store_msg(
          Kerilex.kel_ilk(),
          Kerilex.kel_ilk() | nil,
          Jason.OrderedObject.t(),
          map(),
          KeyStateCache.t()
        ) ::
          {:ok, Kerilex.said() | nil, KeyStateCache.t(), log_response()}
          | {:out_of_order, Kerilex.said(), Jason.OrderedObject.t()}
          | {:error, String.t()}
          | {:duplicity, Kerilex.pre(), Kerilex.int_sn(), Jason.OrderedObject.t(),
             KeyStateStore.stored_event()}
  defp maybe_store_msg(event_type, found_type, msg_obj, parsed_msg, state_cache)

  defp maybe_store_msg("ixn", nil = _found_type, msg_obj, parsed_msg, state_cache) do
    with {:ok, ixn_event} <- IxnEvent.from_ordered_object(msg_obj),
         pref = ixn_event["i"],
         curr_key_state <- state_cache |> KeyStateCache.get_key_state(pref),
         :ok <- check_key_state_found(curr_key_state, pref, "ixn", ixn_event["d"]),
         {:ok, key_state} <- KeyState.new(ixn_event, nil, nil, curr_key_state),
         :ok <-
           IxnEvent.check_sigs(parsed_msg, curr_key_state) do
      state_cache = state_cache |> KeyStateCache.put_key_state(pref, key_state)

      KeyStateStore.update_kel({pref, ixn_event["s"]}, ixn_event)
      |> handle_update_kel_res(ixn_event, state_cache)
    end
  end

  defp maybe_store_msg("icp", nil = _found_type, msg_obj, parsed_msg, state_cache) do
    with {:ok, sig_th} <- KELParser.check_sigs_on_stateful_msg(msg_obj, parsed_msg),
         {:ok, icp_event} <- IcpEvent.from_ordered_object(msg_obj),
         {:ok, key_state} <- KeyState.new(icp_event, sig_th, parsed_msg, KeyState.new()) do
      state_cache = state_cache |> KeyStateCache.put_key_state(msg_obj["i"], key_state)

      {icp_event["i"], 0}
      |> KeyStateStore.update_kel(icp_event)
      |> handle_update_kel_res(icp_event, state_cache)
    end
  end

  defp maybe_store_msg("dip", nil = _found_type, msg_obj, parsed_msg, state_cache) do
    with {:ok, sig_th} <- KELParser.check_sigs_on_stateful_msg(msg_obj, parsed_msg),
         {:ok, dip_event} <- DipEvent.from_ordered_object(msg_obj),
         {:ok, key_state} <- KeyState.new(dip_event, sig_th, parsed_msg, KeyState.new()),
         {:ok, [ssc]} <- KELParser.get_source_seal_couples(parsed_msg),
         :ok <- KeyStateStore.check_seal(dip_event["di"], ssc, KeyStateEvent.seal(dip_event)) do
      state_cache = state_cache |> KeyStateCache.put_key_state(msg_obj["i"], key_state)

      {dip_event["i"], 0}
      |> KeyStateStore.update_kel(dip_event)
      |> handle_update_kel_res(dip_event, state_cache)
    else
      {:event_not_found, _ssc = {_sn, msg_said}} ->
        # handle this as an out-of-order now that events in the kel can come out of order
        # this will be useful as well for the superseding recovery!
        {:out_of_order, msg_said, msg_obj}

      error ->
        error
    end
  end

  defp maybe_store_msg("drt", nil = _found_type, msg_obj, parsed_msg, state_cache) do
    with {:ok, drt_event} <-
           DrtEvent.from_ordered_object(msg_obj),
         {:ok, di} <- fetch_key_from_state_cache(state_cache, drt_event["i"], :di),
         {:ok, [ssc]} <- KELParser.get_source_seal_couples(parsed_msg),
         :ok <- KeyStateStore.check_seal(di, ssc, KeyStateEvent.seal(drt_event)) do
      do_rot_event_update_kel(drt_event, parsed_msg, state_cache)
    else
      {:event_not_found, _ssc = {_sn, msg_said}} ->
        # handle this as an out-of-order now that events in the kel can come out of order
        # this will be useful as well for the superseding recovery!
        # {:error, "anchoring event not found, seal source couple='#{inspect(ssc)}'"}
        {:out_of_order, msg_said, msg_obj}

      err ->
        err
    end
  end

  defp maybe_store_msg("rot", nil = _found_type, msg_obj, parsed_msg, state_cache) do
    case RotEvent.from_ordered_object(msg_obj) do
      {:ok, rot_event} ->
        do_rot_event_update_kel(rot_event, parsed_msg, state_cache)
    end
  end

  defp maybe_store_msg("rot", "ixn", msg_obj, parsed_msg, state_cache) do
    # A0. Any rotation event may supersede an interaction event at the same sn
    # where that interaction event is not before any other rotation event.
    pre = msg_obj["i"]
    sn = msg_obj["s"]

    # this rule is snow checked upstream using KeyState
    # if KeyStateStore.has_event_after?(pre, sn, "rot") do
    #   {:error,
    #    "kel has 'rot' events after the current sn(#{sn}), superseding recovery is not possible"}
    # else
    attempt_recovery = fn ->
      maybe_store_msg("rot", _found_type = nil, msg_obj, parsed_msg, state_cache)
    end

    KeyStateStore.handle_recovery(pre, sn, attempt_recovery)
    |> handle_update_kel_res(msg_obj, state_cache)

    # end
  end

  defp maybe_store_msg(type, nil = _found_type, msg_obj, _parsed_msg, state_cache) do
    {:ok, msg_obj["d"], state_cache,
     %{result: "ignored", reason: "unsupported message type: '#{type}'"}}
  end

  defp maybe_store_msg(type, found_type, msg_obj, _parsed_msg, _state_cache)
       when found_type != nil do
    {:error,
     "event of type '#{type}' can not supersede already existing event of type '#{found_type}', new event said='#{msg_obj["d"]}'"}
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
      |> KeyStateStore.update_kel(rot_event)
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
        {:ok, nil, state_cache, %{type: "rpy", result: "ignored", reason: "already exists"}}

      error ->
        error
    end
  end

  @compile {:inline, handle_update_kel_res: 3}
  defp handle_update_kel_res(res, event_obj, state_cache) do
    case res do
      {:ok, said} ->
        pre = event_obj["i"]
        type = event_obj["t"]
        sn = event_obj["s"]
        {:ok, said, state_cache, %{type: type, result: "updated KEL", pre: pre, sn: sn}}

      # this is now all handled upstream, in `process_kel_msg`
      # :not_updated ->
      #   {:ok, "", state_cache,
      #    %{
      #      type: type,
      #      result: "ignored",
      #      reason: "already exists",
      #      pre: event_obj["i"],
      #      sn: event_obj["s"]
      #    }}

      # {:out_of_order, said} ->
      #   {:out_of_order, said, event_obj}

      # {:duplicity, _pref, _sn, _event, _stored_event} = dup ->
      #   # {:error,
      #   #  "duplicate event detected, already have event '#{type_stored_event}' at sn #{event_obj["s"]}, 'd' is '#{said_stored_event}'"}
      #   dup
      {:failed_recovery, reason} ->
        {:error,
         "recovery attempt failed, reason='#{inspect(reason)}' superseding event pre='#{event_obj["i"]}' 'type='#{event_obj["t"]}' sn='#{event_obj["s"]}' said='#{event_obj["d"]}'"}

      error ->
        error
    end
  end

  # key state response - will not be handled here
  # defp handle_update_ks_res(res, msg_obj) do
  #   type = msg_obj["t"]

  #   case res do
  #     :ok ->
  #       {:ok, %{type: type, result: "updated key state", pre: msg_obj["i"], sn: msg_obj["s"]}}

  #     {:not_updated, stored_sn} ->
  #       {:ok,
  #        %{
  #          type: type,
  #          result: "ignored",
  #          reason: "stored state is newer: #{stored_sn}",
  #          pre: msg_obj["i"],
  #          sn: msg_obj["s"]
  #        }}

  #     error ->
  #       error
  #   end
  # end
end
