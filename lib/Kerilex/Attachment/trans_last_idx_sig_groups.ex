defmodule Kerilex.Attachment.TransLastIdxSigGroups do
  @moduledoc """
    '-H' Composed Base64 Group, pre+ControllerIdxSigs group
  """
  alias Kerilex.Attachment.Number
  alias Kerilex.Attachment.IndexedControllerSig
  @code "-H"

  @spec encode(list({Kerilex.pre(), [IndexedControllerSig.t()]})) ::
          {:ok, iodata()} | {:error, String.t()}
  def encode(groups) when is_list(groups) do
    res =
      groups
      |> Enum.reduce_while(
        [],
        fn {pre, sigs}, groups ->
          encode_group(pre, sigs)
          |> case do
            {:ok, group} ->
              {:cont, [group | groups]}

            error ->
              {:halt, error}
          end
        end
      )

    count_res = length(groups) |> Number.int_to_b64(maxpadding: 2)

    cond do
      match?({:error, _}, res) ->
        res

      match?({:error, _}, count_res) ->
        count_res

      true ->
        {:ok, qb64gc} = count_res
        {:ok, [@code, qb64gc, Enum.reverse(res)]}
    end
  end

  alias Kerilex.Attachment.IndexedControllerSigs, as: ICS

  defp encode_group(pre, ctrl_idx_sigs) when is_list(ctrl_idx_sigs) do
    ICS.encode(ctrl_idx_sigs)
    |> case do
      {:ok, enc_sigs} ->
        {:ok, [pre, enc_sigs]}

      error ->
        error
    end
  end

  # defp encode_group(pre, _sigs) do
    # {:error, "transferable pre is required, got :#{pre}"}
  # end
end
