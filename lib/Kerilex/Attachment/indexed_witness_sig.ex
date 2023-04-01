defmodule Kerilex.Attachment.IndexedWitnessSig do
  defstruct sig: nil, ind: nil

  alias Kerilex.Attachment.Signature

  def new({type, sig_data} = sig, ind)
      when is_atom(type) and
             byte_size(sig_data) > 0 and
             is_integer(ind) and
             ind >= 0 do
      %__MODULE__{sig: sig, ind: ind}
  end

  def encode(%__MODULE__{} = wit_sig) do
    with :ok <- wit_sig |> validate,
         {:ok, _} = res <-
           Signature.to_idx_sig(wit_sig.sig, wit_sig.ind, nil) do
      res
    else
      error ->
        error
    end
  end

  def encode(something) do
    {:error, "wrong argument type, expected %IndexedWitnessSig, got:#{inspect(something)}"}
  end

  defp validate(wit_sig) do
    cond do
      wit_sig.sig == nil and wit_sig.ind == nil ->
        {:error, "sig's 'ind' and 'sig' fields are empty"}

      wit_sig.sig == nil ->
        {:error, "the 'sig' field is empty"}

      wit_sig.ind == nil ->
        {:error, "sig's 'ind' is empty"}

      true ->
        :ok
    end
  end
end
