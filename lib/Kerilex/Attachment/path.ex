defmodule Kerilex.Attachment.Path do
  @moduledoc """
    CESR Proof Signatures helpers

    Allows adding signatures for embedded parts parts of a KERI or ACDC message/credential

  """
  import Integer, only: [mod: 2]
  import Kerilex.Attachment.Number

  def to_qb64!(path_elements)
      when is_list(path_elements) do
    path = build_path!(path_elements)
    size = byte_size(path)

    ps = (4 - mod(size, 4)) |> mod(4)

    code =
      case (ps * 6) |> div(8) do
        0 -> "4A"
        1 -> "5A"
        2 -> "6A"
      end

    count =
      (size + ps)
      |> div(4)
      |> int_to_b64!(2)

    code <> count <> :binary.copy("A", ps) <> path
  end

  defp build_path!([]), do: "-"

  defp build_path!(elements) do
    for pe <- elements, reduce: "" do
      path ->
        path <>
          "-" <>
          cond do
            is_integer(pe) ->
              Integer.to_string(pe)

            is_binary(pe) ->
              pe

            true ->
              raise ArgumentError, message: "expected string or an integer"
          end
    end
  end

  Enum.each(["4A", "5A", "6A"], fn code ->
    def parse(<<unquote(code), _, _, path::binary>>), do: split(path)
  end)

  defp split(path) do
    [_ | pel] = String.split(path, "-")

    for pe <- pel, into: [] do
      case Integer.parse(pe) do
        {ind, _} -> ind
        :error -> pe
      end
    end
  end
end
