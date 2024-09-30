defmodule Kerilex.Attachment.Signature do
  @moduledoc """
    create proper CESR Attachments for signatures
  """
  alias Kerilex.Crypto.Ed25519Sig, as: EdSig
  alias Kerilex.Crypto.Ed25519, as: Ed

  @type sig_type :: :ed25519
  @typedoc """
    tuple {sig_type, signature}
  """
  @type t :: {sig_type(), binary()}

  def parse(<<att::bitstring>>, sig_container) do
    # TODO(VS): handle other signature types
    cond do
      EdSig.code_match?(att) ->
        EdSig.parse(att, sig_container)

      true ->
        <<code::binary-size(2), _::bitstring>> = att
        {:error, "unsupported signature code: #{code}"}
    end
  end

  def valid?(sig, data, raw_pk) when is_tuple(sig) do
    # TODO(VS): handle other sig types
    sig |> EdSig.valid?(data, raw_pk)
  end

  alias Kerilex.Crypto

  def check_with_qb64key({sig_type, _} = sig, data, key_qb64) do
    with {:ok, raw_key, key_type} <-
           key_qb64 |> Crypto.to_raw_key(),
         true <-
           if(sig |> valid?(data, raw_key), do: true, else: {:sig_err, key_type, sig_type}) do
      :ok
    else
      {:sig_err, key_type, sig_type} when key_type != sig_type ->
        {:error, "sig type mismatch, key:#{inspect(key_type)} sig:#{inspect(sig_type)} "}

      {:sig_err, _, _} ->
        {:error, ""}

      error ->
        error
    end
  end

  ################################ encoding #########################

  @ed_sig_type Ed.type()

  def to_idx_sig({@ed_sig_type, sig}, ind, oind) do
    EdSig.to_idx_sig(sig, ind, oind)
  end

  def to_idx_sig({type, _sig}, _ind, _oind) when is_atom(type) do
    unsup_error(type)
  end


  @spec to_signature({atom, any}) ::
          {:error, <<_::64, _::_*8>>} | {:ok, binary | [bitstring, ...]}
  def to_signature({@ed_sig_type, sig}) do
      EdSig.encode(sig)
  end

  def to_signature({type, _sig}) when is_atom(type) do
    unsup_error(type)
  end

  defp unsup_error(type) do
    {:error, "unsupported sig type: #{Atom.to_string(type)}"}
  end
end
