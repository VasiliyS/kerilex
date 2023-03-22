defmodule Kerilex.KEL do
  @moduledoc """
    parser functions for a KERI KEL data
  """

  defstruct msg: "", attach: nil

  alias Kerilex.Attachment, as: Att

  def parse(kel) do
    extract_messages(kel, [])
  end

  defp extract_messages(<<>>, msgs) do
    msgs |> Enum.reverse()
  end

  defp extract_messages(kel, msgs) do
    with {:keri_msg, size} <- sniff_type(kel),
         {:ok, msg, rest_kel} <- extract_message(kel, size),
         {:ok, msg, rest_kel} <- extract_and_parse_att(rest_kel, msg) do
      extract_messages(rest_kel, [msg | msgs])
    end
  end

  defp sniff_type(<<(~S|{"v":"KERI10JSON|), hex_size::binary-size(6), _::bitstring>>) do
    Integer.parse(hex_size, 16)
    |> case do
      :error ->
        {:error, "KERI version, bad size format: #{hex_size}"}

      {size, _} ->
        {:keri_msg, size}
    end
  end

  defp sniff_type(<<"-0", code, _::bitstring>>), do: {:keri_att, code}
  defp sniff_type(<<"-", code, _::bitstring>>), do: {:keri_att, code}
  #TODO(VS): define unknown type handler

  defp extract_message(kel, size) do
    try do
      <<msg::binary-size(size), kel_rest::bitstring>> = kel
      {:ok, %__MODULE__{msg: msg}, kel_rest}
    rescue
      MatchError -> {:error, "wrong msg size, want: #{size}, have: #{byte_size(kel)}"}
    end
  end

  def extract_and_parse_att(kel, msg) do
    kel
    |> Att.parse()
    |> case do
      {:ok, pa, kel_rest} ->
        {:ok, %__MODULE__{msg | attach: pa}, kel_rest}

      error ->
        as =
          kel
          |> byte_size()
          |> min(10)

        {:error, "couldn't parse the attachment: '#{binary_part(kel, 0, as)}...'",
         {:parser_error, error}}
    end
  end
end
