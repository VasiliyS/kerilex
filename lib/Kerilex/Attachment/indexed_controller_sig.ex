defmodule Kerilex.Attachment.IndexedControllerSig do
  @moduledoc """
    defines struct for an Indexed Controller Signature,
    implements encoding logic that is signature type agnostic.
  """

  defstruct sig: nil, ind: nil, oind: nil

  @typedoc """
  Container for thr signatures for the indexed signatures
  - `sig:`: is a tuple {type,sig}, type is e.g. :ed25519
  - `ind:`: signature's index
  - `oind:`: used for a rotated key, where `oind` is "old" index of the
            key's position in the "n" field of the last establishment event
  """
  @type t :: %__MODULE__{
          sig: {:atom, binary()},
          ind: non_neg_integer ,
          oind: non_neg_integer
        }

  alias Kerilex.Attachment.Signature

  def encode(%__MODULE__{} = ctrl_sig) do
    with :ok <- ctrl_sig |> validate,
         {:ok, _} = res <-
           Signature.to_idx_sig(ctrl_sig.sig, ctrl_sig.ind, ctrl_sig.oind) do
      res
    else
      error ->
        error
    end
  end

  def encode(_something) do
    {:error, "wrong argument type, expected %IndexedControllerSig}"}
  end

  defp validate(ctrl_sig) do
    cond do
      ctrl_sig.sig == nil and ctrl_sig.ind == nil ->
        {:error, "sig's 'ind' and 'sig' fields are empty"}

      ctrl_sig.sig == nil ->
        {:error, "the 'sig' field is empty"}

      ctrl_sig.ind == nil ->
        {:error, "sig's 'ind' is empty"}

      true ->
        :ok
    end
  end
end
