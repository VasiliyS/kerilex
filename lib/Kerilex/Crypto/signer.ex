defmodule Kerilex.Crypto.Signer do
  defstruct keypair: nil, qb64: nil

  alias Kerilex.Crypto.{Ed25519, Ed25519Sig}

  def sign(%__MODULE__{keypair: kp}, data)
      when kp != nil and
             is_binary(data) do
    sign_with(kp, data)
  end

  defp sign_with(%Ed25519{secret: sk}, data) do

    sig = data |> Ed25519Sig.sign(sk)
    {:ok, sig}

  end

  defp sign_with(%{}, _) do
    {:error, "unsupported cryptographic algorithm"}
  end
end
