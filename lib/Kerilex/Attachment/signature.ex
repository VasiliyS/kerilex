defmodule Kerilex.Attachment.Signature do
  @moduledoc """
    create proper CESR Attachments for signatures
  """
  alias Kerilex.Attachment.Count
  alias Kerilex.Crypto.Ed25519Sig, as: EdSig

  def nontrans_receipts(receipt_pairs)
      when is_list(receipt_pairs) do
    pairs_count = length(receipt_pairs)

    {receipts_len, receipts} =
      Enum.reduce(
        receipt_pairs,
        {0, ""},
        fn {pre, sig}, {rl, receipts} ->
          rl = rl + byte_size(pre) + byte_size(sig)
          {rl, receipts <> pre <> sig}
        end
      )

    {:ok, pc} = Count.to_nontrans_receipts_couples(pairs_count)
    {:ok, qc} = Count.to_material_quadlets(byte_size(pc) + receipts_len)

    qc <> pc <> receipts
  end

  def parse(<<att::bitstring>>, sig_container) do
    cond do #TODO(VS): handle other signature types
       EdSig.code_match?(att) ->
        EdSig.parse(att, sig_container)

      true ->
        <<code::binary-size(2), _::bitstring>> = att
        {:error, "unsupported signature code: #{code}"}
    end
  end
end
