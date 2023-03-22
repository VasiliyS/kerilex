defmodule Kerilex.Attachment.NonTransReceiptCouples do
  @moduledoc """
    handles "-C##' attachment code: \n
    Count of attached qualified Base64 nontransferable identifier receipt couples pre+sig
  """

  # defstruct receipt_couples: []

  alias Kerilex.Attachment.Number, as: B64
  alias Kerilex.Attachment.NonTransReceiptCouple, as: RC

  @code "-C"

  def code_match?(<<@code, _rest::bitstring>>), do: true
  def code_match?(<<_att::bitstring>>), do: false

  def parse(<<@code, couple_count::binary-size(2), att_rest::bitstring>>) do
    with {:ok, rc_count} <- B64.b64_to_int(couple_count),
         {:ok, _, _ } = res <- get_receipt_couples(rc_count, att_rest, []) do
     res
    else
      error ->
        error
    end
  end

  defp get_receipt_couples(0, att_rest, rcl) do
    {:ok, Enum.reverse(rcl), att_rest}
  end

  defp get_receipt_couples(count, att_rest, rcl) do
    case RC.parse(att_rest) do
      {:ok, rc, att_rest} ->
        get_receipt_couples(count - 1, att_rest, [rc | rcl])

      error ->
        error
    end
  end
end
