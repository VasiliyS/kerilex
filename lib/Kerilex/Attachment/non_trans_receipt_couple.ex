defmodule Kerilex.Attachment.NonTransReceiptCouple do
  @moduledoc """
    Handle Non Transferable Receipt Couples:\n
    pre + sig, which are mainly used for witness `rpy` messages

  """

  alias Kerilex.Attachment.Signature
  alias Kerilex
  alias Kerilex.Attachment.NonTransPrefix, as: NTP

  defstruct pre: nil, sig: nil

  @type t :: %__MODULE__{
          pre: Kerilex.pre(),
          sig: Signature.t()
        }

  @spec new(Kerilex.pre(), Signature.t()) :: Kerilex.Attachment.NonTransReceiptCouple.t()
  def new(pre, sig) do
    %__MODULE__{pre: pre, sig: sig}
  end

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

  ############# encoding ############

  def encode(%__MODULE__{pre: pre, sig: sig}) do
    sig
    |> Signature.to_signature()
    |> case do
      {:ok, sig_enc} ->
        {:ok, [pre, sig_enc]}
      {:error, reason} ->
        {:error, "failed to encode NonTransReceiptCouple: #{reason}"}
    end
  end

  def encode(_something) do
    {:error, "bad argument, expected %NonTransReceiptCouple"}
  end
end
