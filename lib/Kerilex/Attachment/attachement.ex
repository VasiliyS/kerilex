defmodule Kerilex.Attachment do
  @moduledoc """
    Encodes (TODO) and Parses CESR Attachment
  """

  alias Kerilex.Attachment.Number
  require Kerilex.Constants
  import Kerilex.Constants

  @nt_rcpt_couples :nt_rcpt_couples
  @idx_ctrl_sigs :idx_ctrl_sigs
  @idx_wit_sigs :idx_wit_sigs
  @fs_repl_couples :fs_repl_couples
  @seal_src_couples :seal_src_couples

  const(nt_rcpt_couples, @nt_rcpt_couples)
  const(idx_ctrl_sigs, @idx_ctrl_sigs)
  const(idx_wit_sigs, @idx_wit_sigs)
  const(fs_repl_couples, @fs_repl_couples)
  const(seal_src_couples, @seal_src_couples)

  @code "-V"

  def code_match?(<<@code, _rest::bitstring>>), do: true
  def code_match?(<<_att::bitstring>>), do: false

  @parsers %{
    Kerilex.Attachment.NonTransReceiptCouples => @nt_rcpt_couples,
    Kerilex.Attachment.IndexedControllerSigs => @idx_ctrl_sigs,
    Kerilex.Attachment.IndexedWitnessSigs => @idx_wit_sigs,
    Kerilex.Attachment.FirstSeenReplayCouples => @fs_repl_couples,
    Kerilex.Attachment.SealSourceCouples => @seal_src_couples
  }

  @spec parse(<<_::8, _::_*1>>) :: {any(), any()} | {:ok, map(), bitstring()}
  def parse(kel) do
    with {:ok, att, rest_kel} <- kel |> extract,
         {%{} = ap, <<>> = _rest_att} <- attachment_parts(att) do
      {:ok, ap, rest_kel}
    else
      {%{} = _ap, rest_att} ->
        ras = rest_att |> byte_size |> min(10)
        {:error, "unknown parser for: '#{binary_part(rest_att, 0, ras)}...' "}

      error ->
        error
    end
  end

  def extract(<<@code, b64_size::binary-size(2), kel::bitstring>>) do
    kel_size = kel |> byte_size()

    with {:ok, att_quadlets} <- b64_size |> Number.b64_to_int(),
         att_size = att_quadlets * 4,
         # avoid handling MatchError
         {:ok, att_size} <-
           if(att_size <= kel_size, do: {:ok, att_size}, else: {:size_error, att_size}) do
      <<att::binary-size(att_size), rest_kel::bitstring>> = kel
      {:ok, att, rest_kel}
    else
      {:error, _msg} ->
        {:error, "unparsable '#{@code}' size parameter #{b64_size}"}

      {:size_error, att_size} ->
        {:error, "attachment size is too large, want: #{att_size}, got: #{kel_size} bytes"}
    end
  end

  defp attachment_parts(att) do
    # collect all parts and add to the map
    apply_parsers(att, @parsers |> Map.keys(), %{})
  end

  defp apply_parsers(<<>> = att, _parsers, pam) do
    {pam, att}
  end

  defp apply_parsers(att, parsers, pam) do
    {pam, rest_attach, found_parser} =
      parsers
      # try all parsers for this fragment
      |> Enum.reduce_while(
        {pam, att, false},
        fn parser, {pam, rest_attach, found_parser} = acc ->
          if byte_size(rest_attach) == 0 or found_parser do
            {:halt, acc}
          else
            {:cont, apply_parser(parser, {pam, rest_attach})}
          end
        end
      )

    if found_parser == false do
      # we parsed all we could, returning result
      # and the rest that couldn't be parsed
      {pam, rest_attach}
    else
      # try next fragment
      apply_parsers(rest_attach, parsers, pam)
    end
  end

  defp apply_parser(parser, {pam, rest_attach}) do
    if parser.code_match?(rest_attach) do
      # IO.puts "using parser: #{parser}"
      {:ok, st, rest_attach} = parser.parse(rest_attach)
      pa = Map.put(pam, Map.fetch!(@parsers, parser), st)
      {pa, rest_attach, true}
    else
      {pam, rest_attach, false}
    end
  end

  #############   encoding functions ###############

  def encode(parts, opts \\ [iodata: false]) do
    IO.iodata_length(parts)
    |> to_size_quadlets()
    |> case do
      {:ok, size_quadlets} ->
        encoding = [@code, size_quadlets, parts]
        encoding = if(opts[:iodata], do: encoding, else: encoding |> IO.iodata_to_binary())
        {:ok, encoding}

      error ->
        error
    end
  end

  defp to_size_quadlets(size_bytes) do
    if rem(size_bytes, 4) != 0 do
      {:error, "badly formed data, size should be divisible by 4"}
    else
      size_bytes
      |> div(4)
      |> Number.int_to_b64(maxpadding: 2)
    end
  end
end
