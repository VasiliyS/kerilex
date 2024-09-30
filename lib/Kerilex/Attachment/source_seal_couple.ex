defmodule Kerilex.Attachment.SealSourceCouple do
  @moduledoc """
    Deals with seal source couples: \n
      ex: 0AAAAAAAAAAAAAAAAAAAAAABECphNWm1_jZOupeKh6C7TlBi81BlERqbnMpyqpnS4CJY\n
      sequence number  + dig
  """

  alias Kerilex.Attachment.Number

  defstruct seq: nil, dig: nil
  @type t :: %__MODULE__{seq: Kerilex.int_sn(), dig: Kerilex.said()}

  @code "0A"

  def new(seq, dig) do
    %__MODULE__{seq: seq, dig: dig}
  end

  def parse(<<att::bitstring>>) do
    with {:ok, sn, att_rest} <- parse_fn(att),
         {:ok, dt, att_rest} <- parse_pref(att_rest) do
      # {:ok, %__MODULE__{fsn: sn, dt: dt}, att_rest}
      {:ok, {sn, dt}, att_rest}
    end
  end

  defp parse_fn(<<@code, sn::binary-size(22), att_rest::bitstring>>) do
    sn
    |> Number.b64_to_int()
    |> case do
      {:ok, fsn} ->
        {:ok, fsn, att_rest}

      error ->
        error
    end
  end

  defp parse_pref(<<pref::binary-size(44), att_rest::bitstring>>) do
    {:ok, pref, att_rest}
  end

  #############################  encoding ###############################

  def encode(%__MODULE__{seq: seq, dig: dig}) do
    b64_seq = Number.int_to_b64!(seq, 22)
    {:ok, ["0A", b64_seq, dig]}
  end

  def encode(_something) do
    {:error, "bad argument, expected %SealSourceCouple"}
  end
end
