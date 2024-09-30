defmodule Watcher.AIDMonitorReq do
  @moduledoc """
  helper module to create `Req` with the required base parameters.

  E.g. `Finch` connections' pool.
  """

  alias Watcher.AIDMonitor

  @finch_pool_name AIDMonitor.MasterSupervisor.finch_pool_name()

  @doc """
  Create new `Req` with pre-defined `Finch` connections pool

  See `AIDMonitor.MasterSupervisor.init/1` for configuration.
  """
  @spec new(keyword()) :: Req.Request.t()
  def new(opts) when is_list(opts) do
    opts = Keyword.merge(opts, finch: @finch_pool_name)
    Req.new(opts)
  end
end
