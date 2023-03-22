defmodule Kerilex.Crypto do
  @moduledoc """
    deals with keys and seeds
  """
  alias Kerilex.Derivation.Basic

  def get_rnd_seed do
    :enacl.randombytes(32)
    |> Basic.binary_to_seed()
  end

  def get_rnd_salt do
    :enacl.randombytes(16)
    |> Basic.binary_to_salt
  end


end
