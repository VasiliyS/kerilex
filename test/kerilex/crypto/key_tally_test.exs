defmodule Kerilex.Crypto.KeyTallyTest do
  alias Kerilex.Crypto.KeyTally
  use ExUnit.Case

  test "key threshold as number" do
    {:ok, kt} = KeyTally.new(3)
    assert kt |> KeyTally.satisfy?([0, 1, 3]) == true
    assert kt |> KeyTally.satisfy?([5, 6]) == false
  end

  test "key threshold as hex encoded number" do
    {:ok, kt} = KeyTally.new("f")
    assert kt |> KeyTally.satisfy?([0, 1, 3]) == false
    assert kt |> KeyTally.satisfy?(1..15 |> Enum.to_list()) == true
  end

  test "bad thresholds are correctly identified" do
    bad_thresholds = [
      ["1/3", "1/2", []],
      ["1/3", "1/2"],
      [[], []],
      [["1/3", "1/2"], ["1"]],
      [["1/3", "1/2"], []],
      [["1/2", "1/2"], [[], "1"]],
      [["1/2", "1/2", "3/2"]],
      ["1/2", "1/2", "3/2"],
      [["1/2", "1/2", "2/1"]],
      ["1/2", "1/2", "2/1"],
      ["1/2", "1/2", "2"],
      [["1/2", "1/2", "2"]],
      [["1/2", "1/2"], "1"],
      [["1/2", "1/2"], 1],
      [["1/2", "1/2"], "1.0"],
      ["1/2", "1/2", []],
      ["1/2", 0.5]
    ]

    Enum.each(
      bad_thresholds,
      fn tr ->
        assert match?({:error, _}, KeyTally.new(tr))
      end
    )
  end

  describe "single clause threshold check" do
    test "threshold without a 0 weight" do
      {:ok, wkt} = KeyTally.new(["1/2", "1/2", "1/4", "1/4", "1/4"])
      assert wkt |> KeyTally.satisfy?([0, 2, 4])
      assert wkt |> KeyTally.satisfy?([0, 1])
      assert wkt |> KeyTally.satisfy?([1, 3, 4])
      assert wkt |> KeyTally.satisfy?([0, 1, 2, 3, 4])
      assert wkt |> KeyTally.satisfy?([3, 2, 0])
      assert wkt |> KeyTally.satisfy?([0, 0, 1, 2, 1])
      refute wkt |> KeyTally.satisfy?([0, 2])
      refute wkt |> KeyTally.satisfy?([2, 3, 4])
    end


    test "threshold with a 0 weight" do
      {:ok, wkt} = KeyTally.new(["1/2", "1/2", "1/4", "1/4", "1/4", "0"])
      assert wkt |> KeyTally.satisfy?([0, 2, 4])
      assert wkt |> KeyTally.satisfy?([0, 1])
      assert wkt |> KeyTally.satisfy?([1, 3, 4])
      assert wkt |> KeyTally.satisfy?([0, 1, 2, 3, 4])
      assert wkt |> KeyTally.satisfy?([3, 2, 0])
      assert wkt |> KeyTally.satisfy?([0, 0, 1, 2, 1])
      refute wkt |> KeyTally.satisfy?([0, 2, 5])
      refute wkt |> KeyTally.satisfy?([2, 3, 4, 5])
    end
  end
end
