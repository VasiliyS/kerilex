defmodule Kerilex.Crypto.Ed25519 do
  import Comment
  alias Kerilex.Derivation.Basic

  defstruct public: "", secret: ""

  import Kerilex.Constants

  const type, :ed25519

  def new_keypair(<<"0A", _::binary>> = salt) do
    sb = Basic.qb64_to_binary(salt)

    comment("""
    taken from keripy coring.py GenerateSigners
    path = f"{i:x}"
          # algorithm default is argon2id
          seed = pysodium.crypto_pwhash(outlen=32,
                                        passwd=path,
                                        salt=salt,
                                        opslimit=pysodium.crypto_pwhash_OPSLIMIT_INTERACTIVE,
                                        memlimit=pysodium.crypto_pwhash_MEMLIMIT_INTERACTIVE,
                                        alg=pysodium.crypto_pwhash_ALG_DEFAULT)
    """)

    kp =
      :enacl.pwhash(
        "0",
        sb,
        :interactive,
        :interactive,
        :default
      )
      |> :enacl.sign_seed_keypair()

    struct(__MODULE__, kp)
  end

  def new_keypair(<<"A", _::binary>> = seed) do
    kp =
      seed
      |> Basic.qb64_to_binary()
      |> :enacl.sign_seed_keypair()

    struct(__MODULE__, kp)
  end


end
