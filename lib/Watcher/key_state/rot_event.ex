defmodule Watcher.KeyState.RotEvent do
  @moduledoc """
  defines rotation (`rot`) event map for storing in the Key State Store
  """
  @keys Kerilex.Event.rot_labels()

  import Kerilex.Constants

  const(keys, @keys)

  def new do
    Map.from_keys(@keys, nil)
  end

end
