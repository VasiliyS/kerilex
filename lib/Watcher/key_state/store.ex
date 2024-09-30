defmodule Watcher.KeyStateStore do
  @moduledoc """
  persistence layer for all things key state:
  * Backers (endpoints)
  * KSN (latest Key State for a prefix)
  * KEL - key event log for a prefix
  """
  alias Watcher.MnesiaHelpers
  alias Watcher.KeyStateCache
  alias Jason.OrderedObject
  alias Watcher.KeyStateEvent, as: KSE
  alias Watcher.KeyState.Endpoint
  alias Watcher.KeyState
  alias Kerilex.Event
  alias :mnesia, as: Mnesia
  require Logger

  @typedoc """
  stored event is a map which, at a minimum, will have "v", "t", "s", "p" keys.
  """
  @type stored_event :: %{optional(String.t()) => any}

  @persistence_mode :disc_copies
  @ks_table :state
  @backers_table :backers
  @kel_table :kel
  # @anchors_table :anchors

  def check_readiness() do
    MnesiaHelpers.wait_for_tables([@ks_table, @backers_table, @kel_table], timeout: 10_000)
  end

  def init_tables(nodes \\ [node()]) do
    Mnesia.start()
    |> case do
      :ok ->
        with :created <- init_ks_table(nodes),
             :created <- init_backers_table(nodes),
             :created <- init_event_log_table(nodes) do
          :ok
        end

      err ->
        err
    end
  end

  defp init_ks_table(nodes) do
    Mnesia.create_table(
      @ks_table,
      [
        {@persistence_mode, nodes},
        type: :set,
        attributes: ~w[prefix sn state]a
      ]
    )
    |> handle_create_table_res(@ks_table)
  end

  defp init_backers_table(nodes) do
    Mnesia.create_table(
      @backers_table,
      [
        {@persistence_mode, nodes},
        type: :set,
        attributes: ~w[prefix_scheme introduced endpoint]a
      ]
    )
    |> handle_create_table_res(@backers_table)
  end

  defp init_event_log_table(nodes) do
    Mnesia.create_table(
      @kel_table,
      [
        {@persistence_mode, nodes},
        type: :set,
        attributes: ~w[prefix_sn event]a
      ]
    )
    |> handle_create_table_res(@kel_table)
  end

  # maybe do this later to optimize process of checking seals
  # defp init_anchors_table(nodes) do
  #   Mnesia.create_table(
  #     @anchors_table,
  #     [
  #       {@persistence_mode, nodes},
  #       type: :bag,
  #       # stores key = {pref, sn, said}, anchor_data = a map, typically a seal
  #       attributes: ~w[prefix_sn_said anchor_data]a
  #     ]
  #   )
  #   |> handle_create_table_res(@kel_table)
  # end

  defp handle_create_table_res(res, _table) do
    res
    |> case do
      {:atomic, :ok} ->
        :created

      {:aborted, {:already_exists, table}} ->
        Logger.warning("db init, table '#{inspect(table)}' already exists")
        :created

      {:aborted, reason} ->
        {:error, reason}
    end
  end

  ########################   data manipulation and access functions #####################################

  @spec maybe_update_ks(KeyStateCache.t()) :: :ok | {:error, String.t()}
  def maybe_update_ks(ksc) do
    updater = fn ->
      KeyStateCache.get_all_aids(ksc)
      |> Enum.reduce(
        :ok,
        fn pre, _res ->
          ks = KeyStateCache.get_key_state!(ksc, pre)

          Mnesia.read(@ks_table, pre)
          |> do_update_ks(pre, ks)
          |> case do
            {:ok, _prev_state} ->
              :ok

            {:not_updated, :equal_state} ->
              :ok

            {:not_updated, {:stored_fs_gt, sn, _stored_fs, stored_state}} ->
              err = update_ks_error_newer_stored_state(pre, sn, ks, stored_state)
              Mnesia.abort(err)
          end
        end
      )
    end

    Mnesia.transaction(updater)
    |> case do
      {:atomic, :ok} ->
        :ok

      {:aborted, reason} ->
        handle_maybe_update_ks_tr_error(reason)
    end
  end

  defp handle_maybe_update_ks_tr_error(reason) do
    case reason do
      {:error, _} = err ->
        err

      _ ->
        {:error, "failed to update key state in the db: #{reason_to_error(reason)} "}
    end
  end

  defp update_ks_error_newer_stored_state(pre, sn, ks, stored_state) do
    msg = ~s(
     AID='#{pre}' has a newer key state stored at sn='#{sn}', stored state '#{inspect(stored_state)}'
     wanted to update with '#{inspect(ks)}')
    {:error, msg}
  end

  @spec maybe_update_ks(Kerilex.pre(), Watcher.KeyState.t()) ::
          {:ok, KeyState.t()}
          | {
              :not_updated,
              :equal_state
              | {:stored_fs_gt, Kerilex.int_sn(), KeyState.iso8601(), KeyState.t()}
            }
          | {:error, String.t()}
  def maybe_update_ks(prefix, %KeyState{} = state) do
    Mnesia.dirty_read(@ks_table, prefix)
    |> do_update_ks(prefix, state)
  catch
    :exit, {:aborted, reason} ->
      {:error, "lookup for pref failed, #{reason_to_error(reason)}"}
  end

  defp do_update_ks(read_res, prefix, %KeyState{se: sn} = state) do
    case read_res do
      [] ->
        update_ks(prefix, sn, state)

      [{_table, _pref, stored_sn, prev_state}] ->
        cond do
          stored_sn < sn ->
            update_ks(prefix, sn, state, prev_state)

          # could be a recovery
          stored_sn >= sn ->
            update_ks_if_newer(prefix, sn, state, prev_state)
        end
    end
  end

  defp update_ks_if_newer(prefix, sn, state, prev_state) do
    cond do
      prev_state.de == state.de ->
        {:not_updated, :equal_state}

      prev_state.fs < state.fs ->
        update_ks(prefix, sn, state, prev_state)

      prev_state.fs >= state.fs ->
        {:not_updated, {:stored_fs_gt, sn, prev_state.fs, prev_state}}
    end
  end

  defp update_ks(prefix, sn, state, prev_state \\ nil) do
    updater = fn ->
      Mnesia.write({@ks_table, prefix, sn, state})
    end

    if :mnesia.is_transaction() do
      :ok = updater.()
      {:ok, prev_state}
    else
      Mnesia.transaction(updater)
      |> case do
        {:atomic, :ok} ->
          {:ok, prev_state}

        {:aborted, reason} ->
          {:error,
           "failed to write key state record for pref '#{prefix}' at sn '#{sn}', #{reason_to_error(reason)}"}
      end
    end
  end

  def get_ks(pre) do
    case Mnesia.dirty_read(@ks_table, pre) do
      [] ->
        :not_found

      [{_table, _pre, _sn, ks}] ->
        if ks.di != false do
          case get_ks(ks.di) do
            {:ok, pre_ks_list} ->
              {:ok, [{pre, ks} | pre_ks_list]}

            :not_found ->
              {:error, "key state for delegator AID='#{ks.di}' not found."}

            {:error, _} = err ->
              err
          end
        else
          {:ok, [{pre, ks}]}
        end
    end
  catch
    :exit, {:aborted, reason} ->
      {:error, "lookup for AID pref='#{pre}' failed: #{reason_to_error(reason)}"}
  end

  @spec update_kel({Kerilex.pre(), integer()}, map()) ::
          {:ok, Kerilex.said()}
          # | :not_updated
          | {:error, String.t()}
  def update_kel(key, event) when is_tuple(key) do
    updater = fn ->
      Mnesia.write({@kel_table, key, event})
    end

    Mnesia.transaction(updater)
    |> case do
      {:atomic, :ok} ->
        {:ok, event["d"]}

      {:aborted, reason} ->
        {:error,
         "failed to write new kel entry for pref '#{key |> elem(0)}', #{reason_to_error(reason)}"}
    end
  end

  @spec find_event(Kerilex.pre(), non_neg_integer()) ::
          :key_event_not_found
          | {:key_event_found, map()}
          | {:error, String.t()}
  def find_event(pref, sn) do
    Mnesia.dirty_read(@kel_table, {pref, sn})
    |> case do
      [] ->
        :key_event_not_found

      [{_table, _key, stored_event}] ->
        {:key_event_found, stored_event}
    end
  catch
    :exit, {:aborted, reason} ->
      {:error,
       "failed to find parent event for pref '#{pref}' at sn '#{sn}', #{reason_to_error(reason)}"}
  end

  @spec has_event?(Kerilex.pre(), Kerilex.int_sn(), Kerilex.said()) ::
          boolean() | {:error, String.t()}
  def has_event?(pre, sn, said) do
    head_match = {@kel_table, {pre, sn}, %{"d" => said}}
    guard = []
    result = {:const, true}

    Mnesia.dirty_select(@kel_table, [{head_match, guard, [result]}])
    |> case do
      [true] ->
        true

      [] ->
        false
    end
  catch
    :exit, {:aborted, reason} ->
      {:error, "db lookup failed, #{reason_to_error(reason)}"}
  end

  @spec check_parent(Kerilex.pre(), non_neg_integer(), Jason.OrderedObject.t()) ::
          {:no_parent_event, Kerilex.said()} | :ok | {:error, String.t()}
  @doc """
  check that there is a previous event (sn -1) and that it's `said` is equal to the `p` field of the given event
  """
  def check_parent(pref, sn, event) do
    Mnesia.dirty_read(@kel_table, {pref, sn - 1})
    |> case do
      [] ->
        {:no_parent_event, event["p"]}

      [{_table, _key, stored_event}] ->
        if stored_event["d"] == event["p"] do
          :ok
        else
          {:error,
           "event for pref '#{pref}' at sn '#{sn}' failed parent hash check. 'p' is '#{event["d"]}', should be '#{stored_event["d"]}'"}
        end
    end
  catch
    :exit, {:aborted, reason} ->
      {:error,
       "failed to find parent event for pref '#{pref}' at sn '#{sn}', #{reason_to_error(reason)}"}
  end

  @spec validate_config(Kerilex.pre(), Jason.OrderedObject.t()) ::
          :no_icp_event | :ok | {:error, String.t()}
  @doc """
  Validates if config rules of the inception event ('icp' or 'dip') allow adding given event type to the KEL.

  """
  def validate_config(pref, %OrderedObject{} = event) do
    Mnesia.dirty_read(@kel_table, {pref, 0})
    |> case do
      [] ->
        :no_icp_event

      [{_table, _key, stored_event}] ->
        conf = Map.fetch!(stored_event, "c")

        if Event.is_event_allowed?(conf, event["t"]) do
          :ok
        else
          {:error,
           "inception config: '#{inspect({conf})}' for pref '#{pref}' disallows adding event type: '#{event["t"]}'"}
        end
    end
  catch
    :exit, {:aborted, reason} ->
      {:error, "failed to find inception event for pref '#{pref}', #{reason_to_error(reason)}"}
  end

  def maybe_update_backers({_prefix, _scheme} = key, %Endpoint{} = endpoint) do
    Mnesia.dirty_read({@backers_table, key})
    |> case do
      [] ->
        update_backers(key, endpoint)

      [{_table, _key, _introduced, o_endpoint}] ->
        if endpoint |> KSE.bada_check?(o_endpoint) do
          update_backers(key, endpoint)
        else
          :not_updated
        end
    end
  catch
    :exit, {:aborted, reason} ->
      {:error, "lookup for pref and scheme failed, #{reason_to_error(reason)}"}
  end

  defp update_backers(key, endpoint) do
    updater = fn ->
      Mnesia.write({@backers_table, key, false, endpoint})
    end

    Mnesia.transaction(updater)
    |> case do
      {:atomic, :ok} ->
        :ok

      {:aborted, reason} ->
        {:error,
         "failed to write new endpoint record for pref '#{key |> elem(0)}', #{reason_to_error(reason)}"}
    end
  end

  def get_backer_url(prefix, opts \\ [scheme: ["http", "https"]]) do
    Keyword.fetch!(opts, :scheme)
    |> Enum.reduce_while(
      nil,
      fn s, _acc ->
        case do_get_backer_url({prefix, s}) do
          {:ok, _url, _introduced} = res ->
            {:halt, res}

          :not_found ->
            {:cont, :not_found}

          {:error, _} = err ->
            {:halt, err}
        end
      end
    )
  end

  defp do_get_backer_url(key) do
    Mnesia.dirty_read(@backers_table, key)
    |> case do
      [] ->
        :not_found

      [{_table, _key, introduced, %Endpoint{URL: url}}] ->
        {:ok, url, introduced}
    end
  catch
    :exit, {:aborted, reason} ->
      {:error,
       "failed to read endpoint record for pref '#{key |> elem(0)}', #{reason_to_error(reason)}"}
  end

  def set_backer_introduced({pre, scheme} = key) do
    transactor = fn ->
      Mnesia.read(@backers_table, key)
      |> case do
        [] ->
          Mnesia.abort(
            {:not_found, "requested witness pre='#{pre}' scheme='#{scheme}' not found"}
          )

        [{_table, _key, introduced, end_point}] ->
          if introduced == true do
            Mnesia.abort(:ok)
          else
            Mnesia.write({@backers_table, key, true, end_point})
          end
      end
    end

    Mnesia.transaction(transactor) |> handle_transaction_res()
  end

  def find_end_point({wit_aid, scheme}, url) do
    head_match = {@backers_table, {wit_aid, scheme}, :_, %{URL: url} }

    Mnesia.dirty_match_object(head_match)
    |> case do
      [_record] ->
        {:ok, wit_aid, scheme, url}

      [] ->
        :not_found
    end
  catch
    :exit, {:aborted, reason} ->
      {:error, "db lookup failed, #{reason_to_error(reason)}"}
  end

  @doc """
  Returns the latest key state for a prefix
  """
  @spec get_state(Kerilex.pre()) :: {:ok, map(), integer()} | :not_found | {:error, String.t()}
  def get_state(prefix) do
    Mnesia.dirty_read(@ks_table, prefix)
    |> case do
      [] ->
        :not_found

      [{_table, _prefix, sn, state}] ->
        {:ok, state, sn}
    end
  catch
    :exit, {:aborted, reason} ->
      {:error, "lookup for pref failed, #{reason_to_error(reason)}"}
  end

  @doc """
  perform recovery event handling and then, if successful,
  delete hanging chain of events after a parent `ixn` or a `drt` event has been superseded
  via recovery
  """
  def handle_recovery(pref, sn, recovery_callback) do
    transactor = fn ->
      with resp when elem(resp, 0) != :error <- recovery_callback.(),
           {:ok, cnt} <- delete_events_starting_at(pref, sn + 1) do
        Logger.warning("deleted #{cnt} events of the AID='#{pref}' starting at sn=#{sn + 1}")
        resp
      else
        {:error, reason} ->
          Mnesia.abort({:recovery_failed, reason})
      end
    end

    Mnesia.transaction(transactor) |> handle_transaction_res()
  end

  defp handle_transaction_res(res) do
    case res do
      {:atomic, res} ->
        res

      {:aborted, reason} when is_tuple(reason) and elem(reason, 0) == :error ->
        # an error tuple returned from a transaction
        reason

      {:aborted, reason} ->
        # dealing with an mnesia error
        {:error, reason_to_error(reason)}
    end
  end

  @doc """
  delete all events for a prefix starting with a given sn
  """
  def delete_events_starting_at(pre, sn) do
    transactor = fn ->
      head_match = {@kel_table, {pre, :"$1"}, :_}
      guard = [{:>=, :"$1", sn}]
      result = :"$1"

      Mnesia.select(@kel_table, [{head_match, guard, [result]}])
      |> Enum.reduce(
        {:ok, 0},
        fn i, {:ok, cnt} ->
          # TODO(VS): add cascading delete for anchored events
          Mnesia.delete({@kel_table, {pre, i}})
          {:ok, cnt + 1}
        end
      )
    end

    Mnesia.transaction(transactor) |> handle_transaction_res()
  end

  @doc """
  check whether KEL has any events of a given type for the given pref and sn+1.
  Type should be an event type (e.g. "rot", etc) or "*" to look for any event
  """
  def has_event_after?(pref, sn, type) do
    spec =
      if type != "*" do
        head_match = {@kel_table, {pref, :"$1"}, %{"t" => :"$2"}}
        guard = [{:>=, :"$1", sn + 1}, {:==, :"$2", type}]
        result = {:const, true}
        {head_match, guard, [result]}
      else
        head_match = {@kel_table, {pref, :"$1"}, :_}
        guard = [{:>=, :"$1", sn + 1}]
        result = {:const, true}
        {head_match, guard, [result]}
      end

    do_select = fn ->
      case Mnesia.select(@kel_table, [spec], 1, :read) do
        {[res], _cont} ->
          res

        {[res | _], _cont} ->
          # this shouldn't really happen as we request 1 result in select
          # the manual says that this is a recommendation, though.
          res

        :"$end_of_table" ->
          false
      end
    end

    Mnesia.transaction(do_select) |> handle_transaction_res()
  end

  @doc """
  checks that we have a matching sealing event in the KEL
  """
  @spec check_seal(Kerilex.pre(), {non_neg_integer(), Kerilex.said()}, map()) ::
          :ok
          | {:event_not_found, tuple()}
          | {:error, String.t()}
  def check_seal(pref, {sn, _said} = seal_source_couple, seal) do
    Mnesia.dirty_read(@kel_table, {pref, sn})
    |> case do
      [] ->
        {:event_not_found, seal_source_couple}

      [{_table, _key, stored_event}] ->
        do_check_seal(stored_event["d"], stored_event["a"], seal_source_couple, seal)
    end
  catch
    :exit, {:aborted, reason} ->
      {:error,
       "failed to find parent event for pref '#{pref}' at sn '#{sn}', #{reason_to_error(reason)}"}
  end

  defp do_check_seal(_said, [], _ssc, _seal) do
    {:error, "'a' field is empty"}
  end

  defp do_check_seal(said, anchors, {_sn, sealing_said}, seal) when said == sealing_said do
    Enum.find_value(
      anchors,
      fn %{} = a ->
        Map.equal?(a, seal)
      end
    )
    |> case do
      nil ->
        {:error, "matching seal not found"}

      true ->
        :ok
    end
  end

  defp do_check_seal(said, _anchors, {_sn, sealing_said} = ssc, _seal)
       when said != sealing_said do
    {:error, "sealing event's said(#{said}) does not match seal source couple(#{inspect(ssc)})"}
  end

  defp reason_to_error(reason) when is_tuple(reason) do
    elem(reason, 0)
    |> Mnesia.error_description()
    |> List.to_string()
  end

  defp reason_to_error(reason), do: inspect(reason)
end
