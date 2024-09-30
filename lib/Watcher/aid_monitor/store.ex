
defmodule Watcher.AIDMonitor.Store do
  @moduledoc """
  manage list of monitored AIDs
  """
  @table :aid_list
  @wait_timeout 2000

  alias Watcher.MnesiaHelpers

  def check_readiness() do
    MnesiaHelpers.wait_for_tables([@table], timeout: @wait_timeout)
  end


  def init(nodes \\ [node()]) do
    :mnesia.create_table(@table,
      disc_copies: nodes,
      type: :set,
      attributes: ~w[aid oobi_url params]a
    )
    |> case do
      {:atomic, _} ->
        :ok

      {:aborted, reason} ->
        {:error, "failed to created table '#{inspect(@table)}', reason: '#{inspect(reason)}'"}
    end
  end

  def add_aid(pre, url, params) do
    if has_aid?(pre) do
      {:error, "AID with prefix='#{pre}' already exists"}
    else
      transactor = fn ->
        :mnesia.write({@table, pre, url, params})
      end

      MnesiaHelpers.do_transaction(transactor)
    end
  end

  def update_aid(pre, opts) when is_list(opts) do
    new_url = Keyword.get(opts, :url)
    new_params = Keyword.get(opts, :params)

    cond do
      new_url == nil and new_params == nil ->
        raise(ArgumentError, "must have at least one of ':url' or ':params' in the 'opts'")

      is_function(new_params) and
          Function.info(new_params, :arity) != 1 ->
        raise(ArgumentError, "updater function must have arity 1")

      true ->
        do_update_aid(pre, new_url, new_params)
    end
  end

  defp do_update_aid(pre, new_url, new_params) do
    transactor = fn ->
      :mnesia.read({@table, pre})
      |> case do
        [] ->
          :mnesia.abort({:error, "AID with prefix='#{pre}' not found"})

        [{_table, _pre, url, params}] ->
          url = new_url || url

          params = params |> do_update_params(new_params)

          :mnesia.write({@table, pre, url, params})
      end
    end

    MnesiaHelpers.do_transaction(transactor)
  end

  defp do_update_params(params, nil = _new_params), do: params
  defp do_update_params(_params, new_params) when not is_function(new_params), do: new_params

  defp do_update_params(params, new_params) do
    try do
      new_params.(params)
    rescue
      _ ->
        :mnesia.abort({:error, "updater function failed"})
    end
  end

  def delete_aid(pre) do
    transactor = fn ->
      :mnesia.delete({@table, pre})
    end

    MnesiaHelpers.do_transaction(transactor)
  end

  def has_aid?(pre) do
    head_match = {@table, pre, :_, :_}
    guard = []
    result = {:const, true}

    :mnesia.dirty_select(@table, [{head_match, guard, [result]}])
    |> case do
      [] ->
        false

      [true] ->
        true
    end
  catch
    :exit, {:aborted, reason} ->
      {:error, "lookup for aid failed, #{MnesiaHelpers.reason_to_error(reason)}"}
  end

  def oobi_url(aid) do
    head_match = {@table, aid, :"$1", :_}
    guard = []
    result = :"$1"

    :mnesia.dirty_select(@table, [{head_match, guard, [result]}])
    |> case do
      [] ->
        :not_found

      [url] ->
        {:ok, url}
    end
  catch
    :exit, {:aborted, reason} ->
      {:error, "lookup for aid failed, #{MnesiaHelpers.reason_to_error(reason)}"}
  end

  def params(aid) do
    head_match = {@table, aid, :_, :"$1"}
    guard = []
    result = :"$1"

    :mnesia.dirty_select(@table, [{head_match, guard, [result]}])
    |> case do
      [] ->
        :not_found

      [url] ->
        {:ok, url}
    end
  catch
    :exit, {:aborted, reason} ->
      {:error, "lookup for aid failed, #{MnesiaHelpers.reason_to_error(reason)}"}
  end

  def params_update(pre, params) do
    update_aid(pre, params: params)
  end

  def select_for_observation(seconds_since_start) do
    head_match = {@table, :"$1", :_, %{interval: :"$2"}}
    guard = [{:==, 0, {:rem, seconds_since_start, :"$2"}}]
    result = :"$1"

    res = :mnesia.dirty_select(@table, [{head_match, guard, [result]}])
    {:ok, res}
  catch
    :exit, {:aborted, reason} ->
      {:error, "lookup for aid failed, #{MnesiaHelpers.reason_to_error(reason)}"}
  end

end
