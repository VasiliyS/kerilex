defmodule Kerilex.Crypto.WeightedKeyThreshold do
  @moduledoc """
  Weighted key threshold
  "kt" or "nt": ["1"], ["1/2", "1/4", "1/4"], [["1/2", "1/2"],["1"]]
  each weight (w) in a clause (e.g. in []) must be 0 <= w <= 1
  and each clause should add to >= 1
  """

  defstruct size: 0, weights: [], sum: 0, ind_ranges: []

end
