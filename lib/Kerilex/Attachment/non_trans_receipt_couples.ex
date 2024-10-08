defmodule Kerilex.Attachment.NonTransReceiptCouples do
  @moduledoc """
    handles "-C##' attachment code: \n
    Count of attached qualified Base64 nontransferable identifier receipt couples pre+sig
  """

  # defstruct receipt_couples: []

  alias Kerilex.Attachment.Number, as: B64
  alias Kerilex.Attachment.NonTransReceiptCouple, as: RC


  @typedoc """
      list of Non-Transferable Receipt Couples
  """
  @type t :: [RC.t()]

  @code "-C"

  def code_match?(<<@code, _rest::bitstring>>), do: true
  def code_match?(<<_att::bitstring>>), do: false

  def parse(<<@code, couple_count::binary-size(2), att_rest::bitstring>>) do
    with {:ok, rc_count} <- B64.b64_to_int(couple_count),
         {:ok, _, _} = res <- get_receipt_couples(rc_count, att_rest, []) do
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

  alias Kerilex.Attachment, as: Att

  def check(receipt_couples, serd_msg) when is_list(receipt_couples) do
    receipt_couples
    |> Enum.with_index()
    |> Enum.reduce_while(
      false,
      fn
        {rcpt_couple, idx}, _acc ->
          if rcpt_couple |> Att.NonTransReceiptCouple.valid?(serd_msg) do
            {:cont, true}
          else
            {:halt, {false, idx}}
          end
      end
    )
    |> case do
      true ->
        :ok

      {false, idx} ->
        {:error, "NonTransReceiptCouple idx: #{idx} failed sig check"}
    end
  end

  #####################  encoding #########################
  alias Kerilex.Attachment.ListEncoder, as: LE


  @spec encode([RC.t()], keyword()) :: {:error, any} | {:ok, binary | iodata()}
  def encode(receipt_pairs, opts \\ [to: :iodata])
      when is_list(receipt_pairs) do
    LE.encode(@code, Kerilex.Attachment.NonTransReceiptCouple, receipt_pairs, opts)
  end
end
