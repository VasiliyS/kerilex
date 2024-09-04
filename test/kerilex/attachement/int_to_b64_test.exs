defmodule Attachment.Number.B64 do
  use ExUnit.Case
  alias Kerilex.Attachment.Number

  @tag timeout: :infinity
  test "padding detection works correctly" do
    Enum.map(
      0..(2 ** 23),
      fn num ->
        calc_vo = Number.test_int_to_b64_padding(num)
        comp_vo = b64_padding(num)

        assert calc_vo == comp_vo,
               "calc [#{inspect(calc_vo)}] != comp [#{inspect(comp_vo)}] for #{num}"
      end
    )
  end

  defp b64_padding(number) do
    {b64, b64_len, _, _} = Number.test_int_to_b64_raw(number)

    ps_b64 = :binary.longest_common_prefix(["AAA", b64])

    {b64, ps_b64, b64_len - ps_b64}
  end
end
