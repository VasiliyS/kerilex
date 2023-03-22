defmodule Kerilex.Attachment.IndexedControllerSigs do
  @moduledoc """
    encoding and decoding of "-A##" counter code:
    Count of attached qualified Base64 indexed controller signatures
  """

  # defstruct sigs: []

  alias Kerilex.Attachment.Number, as: B64
  alias Kerilex.Attachment.Signature

  @code "-A"

  def code_match?(<<@code, _rest::binary>>), do: true
  def code_match?(<<_att::binary>>), do: false

  def parse(<<"-A", sigs_count::binary-size(2), att_rest::binary>>) do
    with {:ok, sigs_count} <- B64.b64_to_int(sigs_count),
         {:ok, sigs_list, att_rest} <- get_signatures(sigs_count, att_rest, []) do
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
    case Signature.parse(att_rest, Kerilex.Attachment.IndexedControllerSig) do
      {:ok, sig, att_rest} ->
        get_signatures(count - 1, att_rest, [sig | sigs])

      error ->
        error
    end
  end
end
