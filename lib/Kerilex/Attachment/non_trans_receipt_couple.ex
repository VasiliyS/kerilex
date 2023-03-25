defmodule Kerilex.Attachment.NonTransReceiptCouple do
  @moduledoc """
    Handle Non Transferable Receipt Couples:\n
    pre + sig, which are mainly used for witness `rpy` messages

  """

  alias Kerilex.Attachment.Signature
  alias Kerilex.Attachment.NonTransPrefix, as: NTP

  defstruct pre: nil, sig: nil

  def parse(<<att::bitstring>>) do
    with {:ok, pre, att_rest} <- parse_pre(att),
         {:ok, sig, att_rest} <- parse_sig(att_rest) do
      {:ok, %__MODULE__{pre: pre, sig: sig}, att_rest}
    end
  end

  defp parse_pre(<<att_rest::bitstring>>) do
    NTP.parse(att_rest)
  end

  defp parse_sig(<<att_rest::bitstring>>) do
    Signature.parse(att_rest, _sig_container = nil)
  end

  def valid?(%__MODULE__{pre: pre, sig: sig}, data) do
    pk = pre |> NTP.to_binary!()
    sig |> Signature.valid?(data, pk)
  end
end
