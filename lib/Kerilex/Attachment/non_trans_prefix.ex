defmodule Kerilex.Attachment.NonTransPrefix do
@moduledoc """
  parser for non transferable 'B' prefixes\n
  Ed25519 non-transferable prefix public signing verification key
"""

@code "B"

  def parse(<<att_rest::bitstring>>) do
    if match?(<<@code, _::bitstring>>, att_rest) do
      try do
        <<pre::binary-size(44), att_rest::bitstring>> = att_rest
        {:ok, pre, att_rest}
      rescue
        MatchError ->
          {:error, "couldn't parse '#{@code}' prefix, wanted 44 bytes, got:#{byte_size(att_rest)} "}
      end
    else
      <<code, _::bitstring>> = att_rest
      {:error, bad_code_msg(code)}
    end
  end

  alias Kerilex.Derivation.Basic

 def to_binary!(pref) do
  pref
  |> to_binary()
  |> case do
    {:error, reason } ->
      raise ArgumentError, reason
    val ->
      val
  end

 end

  def to_binary(<<"B", value::bitstring>>) do
    Basic.decode_qb64_value(value, 1, 0, 44, 0)
  end

  def to_binary(<<head::binary-size(3), _::bitstring>>) do
    {:error, bad_code_msg(head)}
  end

  defp bad_code_msg(code) do
    "can't parse pref, expected: '#{@code}', got: '#{code}...' "
  end

end
