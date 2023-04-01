defmodule Kerilex.Attachment.IndexedWitnessSigs do
  @moduledoc """
    encoding and decoding of "-B##" counter code:
    Count of attached qualified Base64 indexed witness signatures
  """

  # defstruct sigs: []

  alias Kerilex.Attachment.Number, as: B64
  alias Kerilex.Attachment.Signature

  @code "-B"

  def code_match?(<<@code, _rest::bitstring>>), do: true
  def code_match?(<<_att::bitstring>>), do: false

  def parse(<<@code, sigs_count::binary-size(2), att_rest::bitstring>>) do
    with {:ok, sigs_count} <- B64.b64_to_int(sigs_count),
         {:ok, sigs_list, att_rest} <- get_signatures(sigs_count, att_rest, []) do
      # TODO(VS): verify that signatures are actually in order
      # currently assume that the attachment was correctly formed
      # {:ok, %__MODULE__{sigs: sigs_list}, att_rest}
      {:ok, sigs_list, att_rest}
    else
      error ->
        error
    end
  end

  defp get_signatures(0, att_rest, sigs) do
    {:ok, Enum.reverse(sigs), att_rest}
  end

  defp get_signatures(count, att_rest, sigs) do
    case Signature.parse(att_rest, Kerilex.Attachment.IndexedWitnessSig) do
      {:ok, sig, att_rest} ->
        get_signatures(count - 1, att_rest, [sig | sigs])

      error ->
        error
    end
  end

  import Kerilex.Attachment.IndexedSigs

  encode_sigs(@code, Kerilex.Attachment.IndexedWitnessSig)

end
