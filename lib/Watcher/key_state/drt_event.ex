defmodule Watcher.KeyState.DrtEvent do
  @moduledoc """
  defines delegated rotation (`drt`) event map for storing in the Key State Store
  """
  @keys Kerilex.Event.drt_labels()

  import Kerilex.Constants

  const(keys, @keys)

  def new do
    Map.from_keys(@keys, nil)
  end
end
