defmodule Watcher.KeyStateStore do
  @moduledoc """
  persistance layer for all things key state:
  * Backers (endpoints)
  * KSN (latest Key State for a prefix)
  * KEL - key event log for a prefix
  """
  alias Watcher.KeyStateEvent, as: KSE
  alias Watcher.KeyState.Endpoint
  alias :mnesia, as: Mnesia
  require Logger

  @persistence_mode :disc_copies
  @ks_table :state
  @backers_table :backers
  @kel_table :kel
  # @anchors_table :anchors

  def create_schema(nodes \\ [node()]) do
    case :mnesia.system_info(:running_db_nodes) do
      [] ->
        Mnesia.create_schema(nodes)
        |> case do
          {:error, {_node, {:already_exists, node}}} ->
            {:ok, :already_exists, node}

          {:error, reason} ->
            {:error, "failed to create db schema, '#{inspect(reason)}'"}

          res ->
            res
        end

      db_nodes ->
        msg = "cannot create schema, db is running on nodes: '#{inspect(db_nodes)}'"
        {:error, msg}
    end
  end

  def start_db() do
    Mnesia.start()
    |> case do
      :ok ->
        Mnesia.wait_for_tables([@ks_table, @backers_table, @kel_table], 10_000)
        |> case do
          {:timeout, remaining_tables} ->
            {:error, "timeout loading db tables: #{inspect(remaining_tables)}"}

          res ->
            res
        end

      {:error, reason} ->
        {:error, "could not start db, '#{inspect(reason)}'"}
    end
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

      {:error, reason} ->
        {:error, "could not start db, '#{inspect(reason)}'"}
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
        attributes: ~w[prefix_scheme endpoint]a
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

  defp handle_create_table_res(res, table) do
    res
    |> case do
      {:atomic, :ok} ->
        :created

      {:aborted, {:already_exists, table}} ->
        Logger.warning("db init, table '#{inspect(table)}' already exists")
        :created

      {:aborted, reason} ->
        {:error, "failed to create table '#{inspect(table)}', #{inspect(reason)}"}
    end
  end

  ########################   data manipulation and access functions #####################################

  def maybe_update_ks(prefix, sn, event) do
    Mnesia.dirty_read(@ks_table, prefix)
    |> case do
      [] when sn == 0 ->
        update_ks(prefix, sn, event)

      [] when sn > 0 ->
        :out_of_order

      [{_table, _pref, stored_sn, _state}] ->
        if stored_sn <= sn do
          update_ks(prefix, sn, event)
        else
          {:not_updated, stored_sn}
        end

      {:aborted, reason} ->
        {:error, "lookup for pref failed, #{inspect(reason)}"}
    end
  end

  defp update_ks(prefix, sn, event) do
    updater = fn ->
      Mnesia.write({@ks_table, prefix, sn, event})
    end

    Mnesia.transaction(updater)
    |> case do
      {:atomic, :ok} ->
        :ok

      {:aborted, reason} ->
        {:error,
         "failed to write key state record for pref '#{prefix}' at sn '#{sn}', #{inspect(reason)}"}
    end
  end

  @spec maybe_update_kel({Kerilex.pre(), integer()}, map()) ::
          {:ok, binary()}
          | :not_updated
          | {:out_of_order, binary()}
          | {:duplicity, String.t(), String.t(), map(), map()}
          | {:error, String.t()}
  def maybe_update_kel({pref, sn} = key, event) do
    Mnesia.dirty_read(@kel_table, key)
    |> case do
      [] ->
        with :ok <- if(sn > 0, do: validate_config(pref, event), else: :ok),
             :ok <- if(sn > 0, do: check_parent(pref, sn, event), else: :ok) do
          update_kel(key, event)
        else
          # validate_config couldn't find icp event for the prefix
          :no_icp_event ->
            # missing said is the same as pref
            {:out_of_order, pref}

          # returned by check_parent
          :no_parent_event ->
            {:out_of_order, event["p"]}

          error ->
            error
        end

      [{_table, _key, stored_event}] ->
        if stored_event["d"] == event["d"] do
          :not_updated
        else
          #TODO(VS): add superceding recovery handling!
          {:duplicity, pref, sn, event, stored_event}
        end

      {:aborted, reason} ->
        {:error, "lookup for pref and sn failed, #{inspect(reason)}"}
    end
  end

  alias Kerilex.Event

  def check_parent(pref, sn, event) do
    Mnesia.dirty_read(@kel_table, {pref, sn - 1})
    |> case do
      [] ->
        :no_parent_event

      [{_table, _key, stored_event}] ->
        if stored_event["d"] == event["p"] do
          :ok
        else
          {:error,
           "event for pref '#{pref}' at sn '#{sn}' failed parent hash check. 'p' is '#{event["d"]}', should be '#{stored_event["d"]}'"}
        end

      {:aborted, reason} ->
        {:error,
         "failed to find parent event for pref '#{pref}' at sn '#{sn}', #{inspect(reason)}"}
    end
  end

  @doc """
  Validates if config rules of the inception event ('icp' or 'dip') allow adding given event type to the KEL.

  """
  def validate_config(pref, event) do
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

      {:aborted, reason} ->
        {:error, "failed to find inception event for pref '#{pref}', #{inspect(reason)}"}
    end
  end

  defp update_kel(key, event) do
    # stored_event = event |> KS.ordered_object_to_map()

    updater = fn ->
      Mnesia.write({@kel_table, key, event})
    end

    Mnesia.transaction(updater)
    |> case do
      {:atomic, :ok} ->
        {:ok, event["d"]}

      {:aborted, reason} ->
        {:error, "failed to write new kel entry for pref '#{key |> elem(0)}', #{inspect(reason)}"}
    end
  end

  def maybe_update_backers({_prefix, _scheme} = key, %Endpoint{} = endpoint) do
    Mnesia.dirty_read({@backers_table, key})
    |> case do
      [] ->
        update_backers(key, endpoint)

      [{_table, _key, o_endpoint}] ->
        if endpoint |> KSE.bada_check?(o_endpoint) do
          update_backers(key, endpoint)
        else
          :not_updated
        end

      {:aborted, reason} ->
        {:error, "lookup for pref and scheme failed, #{inspect(reason)}"}
    end
  end

  defp update_backers(key, endpoint) do
    updater = fn ->
      Mnesia.write({@backers_table, key, endpoint})
    end

    Mnesia.transaction(updater)
    |> case do
      {:atomic, :ok} ->
        :ok

      {:aborted, reason} ->
        {:error,
         "failed to write new endpoint record for pref '#{key |> elem(0)}', #{inspect(reason)}"}
    end
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

      {:aborted, reason} ->
        {:error, "lookup for pref failed, #{inspect(reason)}"}
    end
  end

  @doc """
  checks that we have a matching sealing event in the KEL
  """
  @spec check_seal(Kerilex.pre(), {non_neg_integer(), binary()}, map()) ::
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

      {:aborted, reason} ->
        {:error,
         "failed to find parent event for pref '#{pref}' at sn '#{sn}', #{inspect(reason)}"}
    end
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
end
