defmodule Watcher.MnesiaHelpers do
  @moduledoc """
  helpers for mnesia db
  """

  def create_schema(nodes \\ [node()]) do
    case :mnesia.system_info(:running_db_nodes) do
      [] ->
        :mnesia.create_schema(nodes)
        |> case do
          {:error, {_node, {:already_exists, node}}} ->
            {:error, :already_exists, node}

          {:error, reason} ->
            {:error, "failed to create db schema, #{reason_to_error(reason)}"}

          res ->
            res
        end

      db_nodes ->
        msg = "cannot create schema, db is running on nodes: '#{inspect(db_nodes)}'"
        {:error, msg}
    end
  end

  def wait_for_tables(tables, opts \\ [timeout: 5000]) when is_list(tables) do
    timeout = Keyword.fetch!(opts, :timeout)
    existing_tables = :mnesia.system_info(:tables) |> MapSet.new()
    tables_wanted = MapSet.new(tables)

    cond do
      not MapSet.subset?(tables_wanted, existing_tables) ->
        {:error,
         "tables: #{inspect(MapSet.difference(tables_wanted, existing_tables) |> MapSet.to_list())} have not been created"}

      true ->
        :mnesia.wait_for_tables(tables, timeout)
        |> case do
          {:timeout, tables} ->
            {:error, "timeout loading tables: '#{inspect(tables)}'"}

          {:error, reason} ->
            {:error, "error loading tables '#{inspect(tables)}', #{inspect(reason_to_error(reason))}"}

          :ok ->
            :ok
        end
    end
  catch
    :exit, {:aborted, reason} ->
      {:error, "failed to check mnesia status, #{inspect(reason)}"}
  end

  def do_transaction(transactor) do
    :mnesia.transaction(transactor)
    |> handle_transaction_res()
  end

  def handle_transaction_res(res) do
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

  def reason_to_error(reason) when is_tuple(reason) do
    elem(reason, 0)
    |> :mnesia.error_description()
    |> List.to_string()
  end

  def reason_to_error(reason), do: inspect(reason)
end
