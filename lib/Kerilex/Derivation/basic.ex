defmodule Kerilex.Derivation.Basic do
  @moduledoc false

  import Kerilex.Constants
  import Integer, only: [mod: 2]

  @rnd_seed "A"
  @nt_pre_ed25519 "B"
  @ver_key_ed25519 "D"
  @rnd_salt "0A"
  @sig_ed25519 "0B"
  @blake3_256_dig "E"
  @tr_pre_ed25519 @blake3_256_dig

  const(rnd_seed, @rnd_seed)
  const(rnd_salt, @rnd_salt)
  const(nt_pre, @nt_pre_ed25519)
  const(ver_key, @ver_key_ed25519)
  const(sig_ed25519, @sig_ed25519)
  const(blake3_256_dig, @blake3_256_dig)
  const(tr_pre, @tr_pre_ed25519)

  def from_qb64(<<@rnd_seed, value::bitstring>>) when byte_size(value) == 43 do
    decode_qb64_value(value, 1, 0, 44, 0)
  end

  def from_qb64(<<@nt_pre_ed25519, value::bitstring>>) when byte_size(value) == 43 do
    decode_qb64_value(value, 1, 0, 44, 0)
  end

  def from_qb64(<<@rnd_salt, value::bitstring>>) when byte_size(value) == 22 do
    decode_qb64_value(value, 2, 0, 24, 0)
  end

  def from_qb64(<<@sig_ed25519, value::bitstring>>) when byte_size(value) == 86 do
    decode_qb64_value(value, 2, 0, 88, 0)
  end

  def from_qb64(<<@ver_key_ed25519, value::bitstring>>) when byte_size(value) == 43 do
    decode_qb64_value(value, 1, 0, 44, 0)
  end

  def from_qb64(<<@blake3_256_dig, value::bitstring>>) when byte_size(value) == 43 do
    decode_qb64_value(value, 1, 0, 44, 0)
  end

  def qbb64_to_binary(<<ucode::binary-size(2), _::bitstring>>) do
    {:error, "unsupported basic derivation code: #{ucode}"}
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
    #TODO(VS): properly handle ls & verify fs to make logic robust
    # currently assumes properly formed qb64: either ps or ls, length, etc
    ps = (hs + ss + ls) |> mod(4)
    pre_pad = String.duplicate("A", ps)

    raw =
      (pre_pad <> data)
      |> Base.url_decode64!()

    len = byte_size(raw)

    binary_part(raw, ps, len - ps)
  end

  ################## encoding helpers ###################

  def to_qb64_seed(seed) when byte_size(seed) == 32 do
    binary_to_qb64(@rnd_seed, seed, 32)
  end

  def to_qb64_salt(salt) when byte_size(salt) == 16 do
    binary_to_qb64(@rnd_salt, salt, 16)
  end

  def to_qb64_ed_nt_pre(pk) when byte_size(pk) == 32 do
    binary_to_qb64(@nt_pre_ed25519, pk, 32)
  end

  def to_qb64_ed_sig(sig) when byte_size(sig) == 64 do
    binary_to_qb64(@sig_ed25519, sig, 64)
  end

  def to_qb64_blake3_dig(data) when byte_size(data) == 32 do
    binary_to_qb64(@blake3_256_dig, data, 32)
  end

  def to_qb64_ed_verkey(pk) when byte_size(pk) == 32 do
    binary_to_qb64(@ver_key_ed25519, pk, 32)
  end

  def binary_to_qb64(code, data, size, opts \\ [iodata: false]) do


    ds = byte_size(data)
    cs = byte_size(code)

    # pre-padding needed to align data to triplets of bytes
    # Base64 is 6 bits, so data has to be a multiple of 24 bits ( 8 * 3 for B domain, 6 * 4 for T domain)
    # in order to avoid padding added by B64 encoding
    ps = (3 - (ds  |> mod(3))) |> mod(3)
    # pre calculate the resulting length of the encoded data
    # in B64 characters, pre-padding chars to be replaced by the code chars
    qb64_len = cs - ps + ((ps + ds) * 8) |> div(6)

    cond do
      ds != size ->
        {:error, "data must be #{size} bytes, got #{ds}"}

      rem(qb64_len, 4) != 0 -> # output length should be a multiple of 4 sixtets (b64 chars)
        {:error, "combined code and data don't align   "}

      true ->

        padding = :binary.copy(<<0>>, ps)

        pb64 =
          if(ps == 0, do: data, else: padding <> data)
          |> Base.url_encode64(padding: false)

        b64 =
          pb64
          |> binary_part(ps, byte_size(pb64) - ps)

        if opts[:iodata] do
          {:ok, [code, b64]}
        else
          {:ok, code <> b64}
        end
    end
  end
end
