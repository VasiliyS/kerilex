defmodule Watcher.KeyState.Seal do
  @moduledoc """
  defines interaction `seal` map for storing in the Key State Store
  as part of a `rot`, `ixn`, etc events
  """
  @keys ~w[d i s]

  import Kerilex.Constants

  const(keys, @keys)

  def new do
    Map.from_keys(@keys, nil)
  end
end
