defmodule Attachment.Number.B64 do
  use ExUnit.Case
  import Attachment.Number

  test "padding detection works correctly" do
    Enum.map(
      0..(2 ** 23),
      fn num ->
        calc_vo = int_to_b64_padding(num)
        comp_vo = b64_padding(num)
        assert calc_vo == comp_vo , "calc [#{inspect(calc_vo)}] != comp [#{inspect(comp_vo)}] for #{num}"
      end
    )
  end
end
