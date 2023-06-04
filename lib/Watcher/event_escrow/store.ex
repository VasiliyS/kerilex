defmodule Watcher.EventEscrow do
  @moduledoc """
  Temporary Storage for events that can't be processed yet.
  E.g. previous event ('p' field) has not yet arrived, etc.
  """

  defstruct store: %{}

  def has_event_waiting_for?(%__MODULE__{} = escrow, p_said) do
    escrow.store
    |> Map.has_key?(p_said)
  end

  def get_event_waiting_for(%__MODULE__{} = escrow, p_said) do
    escrow.store
    |> Map.fetch(p_said)
    |> case do
      {:ok, _} = res -> res
      _ -> {:error, "#{inspect(p_said)} is not in escrow."}
    end
  end

  def add_event(%__MODULE__{} = escrow, p_said, event) do
    store =
      escrow.store
      |> Map.put_new(p_said, event)

    {:ok, %{escrow | store: store}}
  end

  def pop_event_waiting_for({%__MODULE__{} = escrow, p_said}) do
    escrow.store
    |> Map.pop(p_said, nil)
    |> case do
      {nil, _} -> {:error, "#{inspect(p_said)} is not found."}
      {event, store} -> {:ok, event, %{escrow | store: store}}
    end
  end
end
