defmodule Kerilex.Crypto.Ed25519Sig do
  @moduledoc """
    Signature Type and QB64 encoding, decoding
  """
  alias Kerilex.Derivation.Basic, as: QB64
  alias Kerilex.Attachment.Number
  alias Kerilex.Crypto.Ed25519, as: Ed
  import Kerilex.Constants

  # defstruct sig: <<>>
  @sig_type Ed.type()

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
    |> :enacl.sign_verify_detached(data, pk)
  end

  #############  signing functions ################

  def sign(data, sk) when is_binary(sk) and byte_size(sk) == 64 do
    {@sig_type, :enacl.sign_detached(data, sk)}
  end

  ############ encoding functions #################

  def to_idx_sig(sig, ind, nil) do
    with {:ok, b64ind} <- ind |> Number.int_to_b64(maxpadding: 1),
         {:ok, _} = res <- QB64.binary_to_qb64("A#{b64ind}", sig, 64, iodata: true) do
      res
    else
      error ->
        error
    end
  end

  def to_idx_sig(sig, ind, oind) do
    with {:ok, b64ind} <- ind |> Number.int_to_b64(maxpadding: 2),
         {:ok, b64oind} <- oind |> Number.int_to_b64(maxpadding: 2),
         {:ok, _} = res <- QB64.binary_to_qb64("2A#{b64ind}#{b64oind}", sig, 64, iodata: true) do
      res
    else
      error ->
        error
    end
  end

  def encode(sig) do
    QB64.binary_to_qb64("0B", sig, 64, iodata: true)
  end
end
