defmodule Kerilex.Attachment.Number do
  @moduledoc false
  import Bitwise
  import Integer, only: [mod: 2]





  @spec int_to_b64(non_neg_integer, [{:maxpadding, number} | {:nopadding, boolean}]) ::
           {:ok, binary} | {:error, String.t()}
  def int_to_b64(number, opts \\ [nopadding: false])
  def int_to_b64(number, nopadding: np  ) do

    {b64, ps_b64, value_len} = int_to_b64_padding(number)

    if np do
      binary_part(b64, ps_b64, value_len)
    else
      b64
    end

  end

  def int_to_b64(number, maxpadding: max_padded_len) do


    {b64, ps_b64, value_len} = int_to_b64_padding(number)
    b64_len = byte_size(b64)

    res =
      cond do

        # desired length is greater than
        # the num of value b64 chars
        max_padded_len - value_len > 0 ->
          pd = max_padded_len - b64_len

          res =
            cond do
              # should add extra padding
              pd > 0 ->
                :binary.copy("A", pd) <> b64

              # reduce the number of As
              pd < 0 ->
                pd = pd * -1
                binary_part(b64, pd, b64_len - pd)

              # no need to adjust
              true ->
                b64
            end

          {:ok, res}

        # desired length matches the num of b64 chars
        max_padded_len - value_len == 0 ->
          # return just the value chars
          {:ok, binary_part(b64, ps_b64, value_len)}

        # desired length is less than the num of b64 chars
        true ->
          {:error, "requested len:#{max_padded_len} < value len:#{value_len}"}
      end

    res
  end

  def int_to_b64!(number, padded_length) do
    case int_to_b64(number, maxpadding: padded_length) do
      {:ok, b64} -> b64
      {:error, msg} -> raise Attachment.NumberError, message: msg
    end
  end

  def int_to_b64_np(number) do
    {b64, ps_b64, value_len} = int_to_b64_padding(number)
    binary_part(b64, ps_b64, value_len)
  end

  defp int_to_b64_raw(number) do
    bn = :binary.encode_unsigned(number, :big)
    bs = byte_size(bn)
    # number of prep'ed 0 bytes in the B domain
    ps = (3 - (bs |> mod(3))) |> mod(3)

    bn = :binary.copy(<<0>>, ps) <> bn

    b64 = bn |> Base.url_encode64(padding: false)
    b64_len = b64 |> byte_size()

    {b64, b64_len, ps, bs}
  end

  defp int_to_b64_padding(number) do
    {b64, b64_len, ps, bs} = int_to_b64_raw(number)
    # number of prep'ed As in the T domain algo
    #  created to avoid checking the As via longest_common_prefix :)

    # 8 bit triplets, adjust for big numbers
    base = ((bs * 8 - 1) |> div(24)) * 24
    # check if any bits in a byte for the next sixtet are set
    set_bits = number >>> ((3 - ps) * 6 + base)
    extra_a = if set_bits == 0, do: 1, else: 0
    # adjust the padding size in the T domain
    ps_b64 = ps + extra_a
    value_len = b64_len - ps_b64

    {b64, ps_b64, value_len}
  end

  def b64_padding(number) do
    {b64, b64_len, _, _} = int_to_b64_raw(number)

    ps_b64 = :binary.longest_common_prefix(["AAA", b64])

    {b64, ps_b64, b64_len - ps_b64}
  end

  def b64_to_int(data) when is_binary(data) do
    # calculate amount of 'A' padding to prepend
    ps = (4 - (byte_size(data) |> mod(4))) |> mod(4)

    data = if ps > 0, do: :binary.copy("A", ps) <> data, else: data

    case data |> Base.url_decode64(padding: false) do
      {:ok, enc_val} ->
        {:ok, enc_val |> :binary.decode_unsigned(:big)}

      :error ->
         ds =
         data
         |> byte_size()
         |> min(10)
        {:error, "can't url_decode qb64 data: '#{binary_part(data,0,ds)}...'"}
    end
  end
end
