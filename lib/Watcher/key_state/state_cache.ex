defmodule Watcher.KeyStateCache do
  @moduledoc """
  defines methods to hold the calculated KeyStates
  during the OOBI process

  note: OOBI key event log can hold establishment events for delegated `aid`s
  """
  alias Watcher.KeyState

  @opaque t :: %__MODULE__{cache: map()}
  @doc false
  defstruct cache: %{}

  @doc """
  create an empty `KeySateCache`
  """
  @spec new():: t()
  def new do
    %__MODULE__{}
  end

  @doc """
  add put `KeyState` into the cache for a prefix
  """
  @spec put_key_state(t(), Kerilex.pre(), KeyState.t()) :: t()
  def put_key_state(key_state_cache, pref, key_state)

  def put_key_state(%__MODULE__{cache: c} = ksc, pre, %KeyState{} = ks) do
    %__MODULE__{ksc | cache: Map.put(c, pre, ks)}
  end

  @doc """
  returns current `KeyState` for a prefix, if any
  """
  @spec get_key_state(t(), Kerilex.pre()) :: KeyState.t() | nil
  def get_key_state(key_state_cache, pref)

  def get_key_state(%__MODULE__{cache: c}, pref) do
    Map.get(c, pref)
  end
end
