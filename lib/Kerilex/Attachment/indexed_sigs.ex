defmodule Kerilex.Attachment.IndexedSigs do
  @moduledoc """
    common utility macros and functions for all indexed signatures
  """
  alias Kerilex.Attachment.Number

  defmacro encode_sigs(cesr_code, indexed_sig_module) do
    quote do
      def encode(sigs, opts \\ [to: :iodata]) when is_list(sigs) do
        head = unquote(cesr_code)

        with {:ok, b64count} <- length(sigs) |> Number.int_to_b64(maxpadding: 2),
             {:ok, b64sigs} <- sigs |> encode_sigs do
          encoding = [head, b64count, b64sigs]

          res =
            if opts[:to] == :iodata do
              encoding
            else
              encoding |> to_string
            end

          {:ok, res}
        else
          error ->
            error
        end
      end

      defp encode_sigs(sigs) do
        sigs
        |> Enum.reduce_while(
          [],
          fn sig, sigs ->
            sig
            |> unquote(indexed_sig_module).encode
            |> case do
              {:ok, sig} ->
                {:cont, [sig | sigs]}

              error ->
                {:halt, error}
            end
          end
        )
        |> case do
          {:error, _} = err ->
            err

          sigs ->
            {:ok, sigs |> Enum.reverse()}
        end
      end
    end
  end
end
