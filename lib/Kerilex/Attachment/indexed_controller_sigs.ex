defmodule Kerilex.Attachment.IndexedControllerSigs do
  @moduledoc """
    encoding and decoding of "-A##" counter code:
    Count of attached qualified Base64 indexed controller signatures
  """

  # defstruct sigs: []

  alias Kerilex.Attachment.Number, as: B64
  alias Kerilex.Attachment.Signature
  alias Kerilex.Attachment.IndexedControllerSig, as: ICS

  @code "-A"

  def code_match?(<<@code, _rest::binary>>), do: true
  def code_match?(<<_att::binary>>), do: false

  def parse(<<@code, sigs_count::binary-size(2), att_rest::binary>>) do
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
        # IO.puts "error getting idx sig at #{count}, cesr '#{att_rest}'"
        error
    end
  end

  def encode(sigs, opts \\ [to: :iodata]) when is_list(sigs) do
    head = @code

    with {:ok, b64count} <- length(sigs) |> B64.int_to_b64(maxpadding: 2),
         {:ok, b64sigs} <- sigs |> encode_sigs do
      encoding = [head, b64count, b64sigs]

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

  def encode_sigs(sigs) do
    sigs
    |> Enum.reduce_while(
      [],
      fn sig, sigs ->
        sig
        |> ICS.encode()
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
