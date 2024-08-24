defmodule Watcher.EventEscrow do
  @moduledoc """
  Temporary Storage for events that can't be processed yet.
  E.g. previous event ('p' field) has not yet arrived, etc.
  """
  @opaque t :: %__MODULE__{store: %{optional(Kerilex.pre()) => list()}}
  defstruct store: %{}

  alias Jason.OrderedObject

@spec new() :: t()
def new do
  struct(__MODULE__)
end

@spec empty?(Watcher.EventEscrow.t()) :: boolean()
def empty?(%__MODULE__{store: store}), do: store === %{}

@spec has_events_waiting_for?(Watcher.EventEscrow.t(), Kerilex.said()) ::
          boolean()
  def has_events_waiting_for?(%__MODULE__{} = escrow, pre_said_key) do
    escrow.store
    |> Map.has_key?(pre_said_key)
  end

  @spec get_events_waiting_for(Watcher.EventEscrow.t(), Kerilex.said()) ::
          {:error, String.t()} | {:ok, [{OrderedObject.t(), map()}]}
  def get_events_waiting_for(%__MODULE__{} = escrow, p_said) do
    escrow.store
    |> Map.fetch(p_said)
    |> case do
      {:ok, _} = res -> res
      _ -> {:error, "#{inspect(p_said)} is not in escrow."}
    end
  end

  @spec add_event(
          Watcher.EventEscrow.t(),
          Kerilex.said(),
          Jason.OrderedObject.t(),
          map()
        ) ::
          {:ok, Watcher.EventEscrow.t()}
  def add_event(%__MODULE__{} = escrow, p_said, %OrderedObject{} = msg_obj, %{} = parsed_msg) do
    new_dep_event = {msg_obj, parsed_msg}
    store =
      # |> Map.put_new(p_said, {msg_obj, parsed_msg})
      escrow.store
      |> Map.update(p_said, [new_dep_event], fn dep_events -> [new_dep_event | dep_events] end)

    {:ok, %{escrow | store: store}}
  end

  @spec pop_events_waiting_for(Watcher.EventEscrow.t(), Kerilex.said()) ::
          {:error, String.t()} | {:ok, [{OrderedObject.t(), map()}], Watcher.EventEscrow.t()}
  def pop_events_waiting_for(%__MODULE__{} = escrow, pre_said_key) do
    escrow.store
    |> Map.pop(pre_said_key, nil)
    |> case do
      {nil, _} -> {:error, "#{inspect(pre_said_key)} is not found."}
      {value, store} -> {:ok, value, %{escrow | store: store}}
    end
  end
end
