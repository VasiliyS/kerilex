defmodule Watcher.AIDMonitor.KeyStateObserver do
  @moduledoc """
  GenStage ConsumerSupervisor

  Send observations to dynamically allocated workers
  """
  use ConsumerSupervisor

  alias Watcher.AIDMonitor.{KeyStateObserver.Worker, ObservationScheduler}

  def start_link(arg) do
    ConsumerSupervisor.start_link(__MODULE__, arg, name: __MODULE__)
  end

  def init(_arg) do
    children = [%{id: Worker, start: {Worker, :start_link, []}, restart: :temporary}]
    demand = System.schedulers_online()
    opts = [strategy: :one_for_one, subscribe_to: [{ObservationScheduler, max_demand: demand, min_demand: 1}]]
    ConsumerSupervisor.init(children, opts)
  end
end
