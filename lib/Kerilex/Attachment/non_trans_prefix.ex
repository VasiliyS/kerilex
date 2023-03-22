defmodule Kerilex.Attachment.NonTransPrefix do
@moduledoc """
  parser for non transferable 'B' prefixes\n
  Ed25519 non-transferable prefix public signing verification key
"""


  def parse(<<att_rest::bitstring>>) do
    if match?(<<"B", _::bitstring>>, att_rest) do
      try do
        <<pre::binary-size(44), att_rest::bitstring>> = att_rest
        {:ok, pre, att_rest}
      rescue
        MatchError ->
          {:error, "couldn't parse 'B' prefix, wanted 44 bytes, got:#{byte_size(att_rest)} "}
      end
    else
      <<code, _::bitstring>> = att_rest
      {:error, "expected 'B', got '#{code}'"}
    end
  end

end
