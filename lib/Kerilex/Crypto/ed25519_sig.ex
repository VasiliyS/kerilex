defmodule Kerilex.Crypto.Ed25519Sig do
  @moduledoc """
    Signature Type and QB64 encoding, decoding
  """
  alias Kerilex.Derivation.Basic, as: QB64
  alias Kerilex.Attachment.Number
  # alias Kerilex.Attachment.IndexedControllerSig, as: ICS

  defstruct sig: <<>>
  @sig_type :ed25519

  # TODO(VS): extend to handle rotation sigs (2A + ind + oind)
  def indexed_sign(data, ind, sk) do
    with {:ok, ind} <- Number.int_to_b64(ind, maxpadding: 1),
         sig <- sign(data, sk) do
      QB64.binary_to_qb64("A#{ind}", sig, 64)
    end
  end

  def self_sign(data, sk) do
    sig = sign(data, sk)
    QB64.binary_to_qb64("0B", sig, 64)
  end

  defp sign(data, sk) when is_binary(sk) and byte_size(sk) == 64 do
    :enacl.sign_detached(data, sk)
  end

  def code_match?(<<"A", _::bitstring>>), do: true
  def code_match?(<<"0B", _::bitstring>>), do: true
  def code_match?(<<"2A", _::bitstring>>), do: true
  def code_match?(<<_::bitstring>>), do: false

  def parse(
        <<"A", ind::binary-size(1), b64_sig::binary-size(86), att_rest::bitstring>>,
        sig_container
      ) do
    with {:ok, idx} <- Number.b64_to_int(ind),
         sig <- b64_sig |> QB64.decode_qb64_value(1, 1, 88, 0) do
      # sm = %__MODULE__{sig: sig}
      sm = {@sig_type, sig}
      {:ok, struct(sig_container, ind: idx, sig: sm), att_rest}
    end
  end

  def parse(
        <<"2A", ind::binary-size(2), oind::binary-size(2), b64_sig::binary-size(86),
          att_rest::bitstring>>,
        sig_container
      ) do
    with {:ok, idx} <- Number.b64_to_int(ind),
         {:ok, oidx} <- Number.b64_to_int(oind),
         sig <- b64_sig |> QB64.decode_qb64_value(1, 1, 88, 0) do
      # edsig = %__MODULE__{sig: sig}
      edsig = {@sig_type, sig}
      {:ok, struct(sig_container, sig: edsig, ind: idx, oind: oidx), att_rest}
    end
  end

  def parse(<<"0B", b64_sig::binary-size(86), att_rest::bitstring>>, _sig_container) do
    sig = b64_sig |> QB64.decode_qb64_value(1, 1, 88, 0)
    {:ok, {@sig_type, sig}, att_rest}
  end


  def valid?({@sig_type, sig}, data, pk) do
    sig
    |>:enacl.sign_verify_detached(data, pk)
  end
end
