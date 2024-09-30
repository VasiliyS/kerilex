defmodule Watcher.AIDMonitor.Initializer do
  @moduledoc """
  Initialization GenServer that ensures:
  - DBs required for AIDMonitor are all available
  """
  alias Watcher.KeyStateStore
  alias Watcher.AIDMonitor.Store, as: MonitorStore
  use GenServer, restart: :temporary, significant: true

  require Logger

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    with :ok <- MonitorStore.check_readiness(),
         :ok <- KeyStateStore.check_readiness() do
      Logger.info(%{msg: "all tables are ready"})
      :ignore
    else
      err ->
        Logger.error(%{msg: "failed to start db", error: err})
        {:stop, err}
    end
  end
end

defmodule Watcher.AIDMonitor.GenStageSupervisor do
  @moduledoc """
  Supervisor for the GenStage part of the AID Monitor

  ensures that potential restarts are done in the right sequence
  to enable auto-subscription
  """
  use Supervisor

  alias Watcher.AIDMonitor.{KeyStateObserver, ObservationScheduler}

  def start_link(opts) do
    name = Keyword.get(opts, :name, __MODULE__)
    Supervisor.start_link(__MODULE__, :ok, name: name)
  end

  @impl true
  def init(:ok) do
    children = [
      ObservationScheduler,
      KeyStateObserver
    ]

    Supervisor.init(children, strategy: :rest_for_one)
  end
end

defmodule Watcher.AIDMonitor.MasterSupervisor do
  @moduledoc """
  Supervisor Tree for all the AID Monitor processes
  """

  use Supervisor

  alias Watcher.AIDMonitor.{Initializer, GenStageSupervisor}
  alias Watcher.AIDMonitor.KeyStateUpdater.Pool, as: KeyStateUpdaterPool

  @finch_pool_name WitnessConnections

  def finch_pool_name, do: @finch_pool_name

  def start_link(opts) do
    name = Keyword.get(opts, :name, __MODULE__)
    Supervisor.start_link(__MODULE__, :ok, name: name)
  end

  @impl true
  def init(:ok) do
    children = [
      Initializer,
      {Finch, name: @finch_pool_name, pools: %{default: [pool_max_idle_time: 60_000]}},
      KeyStateUpdaterPool,
      GenStageSupervisor
    ]

    Supervisor.init(children, strategy: :one_for_one, auto_shutdown: :any_significant)
  end
end
