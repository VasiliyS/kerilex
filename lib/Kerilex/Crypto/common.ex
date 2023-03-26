defmodule Kerilex.Crypto do
  @moduledoc """
    deals with keys and seeds
  """
  alias Kerilex.Derivation.Basic
  alias Kerilex.Crypto.Ed25519, as: Ed

  def get_rnd_seed do
    :enacl.randombytes(32)
    |> Basic.binary_to_seed()
  end

  def get_rnd_salt do
    :enacl.randombytes(16)
    |> Basic.binary_to_salt()
  end

  def to_raw_key(qb46key) do
    cond do
      String.starts_with?(qb46key, ["B", "D"]) ->
        {:ok, Basic.qb64_to_binary(qb46key), Ed.type()}

      true ->
        {:error, "unknown key type"}
    end
  end
end
