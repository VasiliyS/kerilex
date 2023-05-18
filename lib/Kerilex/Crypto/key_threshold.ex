defmodule Kerilex.Crypto.KeyThreshold do
  @moduledoc """
  unweighted threshold
  e.g. "kt": 1, "kt": "1", "kt": 2 - 2 of n key are enough, etc
  if value of "kt", or "nt" is a string, the encoded number is base 16
  """
  defstruct threshold: nil
end
