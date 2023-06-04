defmodule Watcher.KeyState.IxnEvent do
  @moduledoc """
  defines interaction (`ixn`) event map for storing in the Key State Store
  """
  @keys Kerilex.Event.ixn_labels()

  import Kerilex.Constants

  const(keys, @keys)

  def new do
    Map.from_keys(@keys, nil)
  end
end
