defmodule Kerilex.Attachment.ListEncoder do
  @moduledoc """
    common utility macros and functions for all counted list,
    e.g.: IndexedSigs, ReceiptCouples, etc.
  """
  alias Kerilex.Attachment.Number

  def encode(cesr_code, module, list, opts \\ [to: :iodata])
      when is_list(list) and is_atom(module) do
    head = cesr_code

    with {:ok, b64count} <- length(list) |> Number.int_to_b64(maxpadding: 2),
         {:ok, b64list} <- list |> encode_list(module) do
      encoding = [head, b64count, b64list]

      res =
        if opts[:to] == :iodata do
          encoding
        else
          encoding |> IO.iodata_to_binary()
        end

      {:ok, res}
    else
      error ->
        error
    end
  end

  defp encode_list(list, module) do
    list
    |> Enum.reduce_while(
      [],
      fn item, list ->
        item
        |> module.encode
        |> case do
          {:ok, item} ->
            {:cont, [item | list]}

          error ->
            {:halt, error}
        end
      end
    )
    |> case do
      {:error, _} = err ->
        err

      list ->
        {:ok, list |> Enum.reverse()}
    end
  end
end
