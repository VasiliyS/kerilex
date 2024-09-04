defmodule Kerilex.Event.SerializeTest do
  use ExUnit.Case

  alias Kerilex.Event

  @backer_icp ~S|{"v":"KERI10JSON0000fd_","t":"icp","d":"EDyvAMpba1ZJbgvwxb6hUBsycgsQfxUdk-Yi2AYod4k7","i":"BP-nOCxB--MKSgwTXyLj01zA5jkG0Gb-8h-SHDX4qCJO","s":"0","kt":"1","k":["BP-nOCxB--MKSgwTXyLj01zA5jkG0Gb-8h-SHDX4qCJO"],"nt":"0","n":[],"bt":"0","b":[],"c":[],"a":[]}|

  test "inception event for a non-trans prefix serializes correctly" do
    {:ok, res, _said} =
      Event.Inception.encode(
        "BP-nOCxB--MKSgwTXyLj01zA5jkG0Gb-8h-SHDX4qCJO"
      )

    assert @backer_icp == res
  end
end
