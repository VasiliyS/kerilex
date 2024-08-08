defmodule Kerilex.Crypto.Ed25519Sig do
  @moduledoc """
    Signature Type and QB64 encoding, decoding
  """
  alias Kerilex.Attachment.IndexedControllerSig
  alias Kerilex.Derivation.Basic, as: QB64
  alias Kerilex.Attachment.Number
  alias Kerilex.Crypto.Ed25519, as: Ed
  import Kerilex.Constants

  # defstruct sig: <<>>
  @sig_type Ed.type()

  # TODO(VS): think about different contexts for these codes
  # E.g. 'A' can be used for IndexedWitnessSig or in IndexedControllerSig, if ind == oind
  # see in keripy: src/keri/core/indexing.py (line 55 -72)
  # 'A' Ed25519 sig appears same in both lists if any.
  def code_match?(<<"A", _::bitstring>>), do: true

  # 0B is Ed448 signature appears in current list only, for indexed sigs or *simply ed25519* for NonTransCouples
  def code_match?(<<"0B", _::bitstring>>), do: true
  # '2A'  Ed25519 sig appears in both lists.
  def code_match?(<<"2A", _::bitstring>>), do: true
  # 'B'  Ed25519 sig appears in current list only.
  def code_match?(<<"B", _::bitstring>>), do: true
  def code_match?(<<_::bitstring>>), do: false

  def parse(
        <<"B", ind::binary-size(1), b64_sig::binary-size(86), att_rest::bitstring>>,
        sig_container
      ) do
    do_small_idx_parse(ind, b64_sig, att_rest, sig_container)
  end

  def parse(
        <<"A", ind::binary-size(1), b64_sig::binary-size(86), att_rest::bitstring>>,
        sig_container
      ) do
    with {:ok, idx} <- Number.b64_to_int(ind),
         sig <- b64_sig |> QB64.decode_qb64_value(1, 1, 88, 0) do
      sm = {@sig_type, sig}

      # TODO(VS): need to think if there's a better type handling for the
      # cases where signature code is context dependent
      res =
        if sig_container == IndexedControllerSig do
          struct(sig_container, ind: idx, oind: idx, sig: sm)
        else
          struct(sig_container, ind: idx, sig: sm)
        end

      {:ok, res , att_rest}
    end
  end

  defp do_small_idx_parse(ind, b64_sig, att_rest, sig_container) do
    with {:ok, idx} <- Number.b64_to_int(ind),
         sig <- b64_sig |> QB64.decode_qb64_value(1, 1, 88, 0) do
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

  # this one is used for NonTransReceiveCouple
  def parse(<<"0B", b64_sig::binary-size(86), att_rest::bitstring>>, nil) do
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
