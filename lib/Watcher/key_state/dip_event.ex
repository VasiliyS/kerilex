defmodule Watcher.KeyState.DipEvent do
  @moduledoc """
  defines delegated inception (`dip`) event map for storing in the Key State Store
  """
  @keys Kerilex.Event.dip_labels()

  import Kerilex.Constants

  const(keys, @keys)

  def new do
    Map.from_keys(@keys, nil)
  end

end
