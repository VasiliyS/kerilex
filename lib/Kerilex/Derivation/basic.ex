defmodule Kerilex.Derivation.Basic do
  @moduledoc false

  def qb64_to_binary(<<"A"::utf8, value::binary>>) do
    decode_qb64_value(value, 1, 0, 44, 0)
  end

  def qb64_to_binary(<<"B"::utf8, value::binary>>) do
    decode_qb64_value(value, 1, 0, 44, 0)
  end

  def qb64_to_binary(<<"0A", value::binary>>) do
    decode_qb64_value(value, 2, 0, 24, 0)
  end

  def qb64_to_binary(<<"0B"::utf8, value::binary>>) do
    decode_qb64_value(value, 2, 0, 88, 0)
  end

  def qb64_to_binary(<<"D"::utf8, value::binary>>) do
    decode_qb64_value(value, 1, 0, 44, 0)
  end

  @doc """
    decodes QB64 string stripped of its leading code into binary

    `hs` is the hard size int number of chars in hard (stable) part of code \n
    `ss` is the soft size int number of chars in soft (unstable) part of code \n
    `fs` is the full size int number of chars in code plus appended material if any \n
      currently not used, assumes correct length of the provided data \n
    `ls` is the lead size int number of bytes to pre-pad pre-converted raw binary
  """
  def decode_qb64_value(data, hs, ss, _fs, ls) do
    # see https://github.com/WebOfTrust/keripy/blob/8a6f67153594ffac0dd3a2ccfbc4fd9235194d79/src/keri/core/coring.py#L1076
    ps = (hs + ss + ls) |> Integer.mod(4)
    pre_pad = String.duplicate("A", ps)

    raw =
      (pre_pad <> data)
      |> Base.url_decode64!()

    len = byte_size(raw)

    binary_part(raw, ps, len - ps)
  end

  def binary_to_seed(seed) do
    binary_to_qb64("A", seed, 32)
  end

  def binary_to_salt(salt) do
    binary_to_qb64("0A", salt, 16)
  end

  def binary_to_ed_non_trans_pk(pk) do
    binary_to_qb64("B", pk, 32)
  end

  def binary_to_ed_sig(sig) do
    binary_to_qb64("0B", sig, 64)
  end

  def binary_to_blake3_dig(data) do
    binary_to_qb64("E", data, 32)
  end

  def binary_to_qb64(code, data, size) do
    case byte_size(data) do
      bs when bs == size ->
        ps = byte_size(code)
        padding = :binary.copy(<<0>>, ps)

        pb64 =
          (padding <> data)
          |> Base.url_encode64(padding: false)
        b64 =
          pb64
          |> binary_part(ps, byte_size(pb64) - ps)

        {:ok, code <> b64}

      bs ->
        {:error, "data must be #{size} bytes, got #{bs}"}
    end
  end
end
