defmodule Kerilex.Crypto do
  @moduledoc """
    deals with keys and seeds
  """

  import Comment
  alias Kerilex.Derivation.Basic
  alias Kerilex.Crypto.Ed25519, as: Ed
  alias Kerilex.Crypto.Signer

  def rnd_seed do
    :enacl.randombytes(32)
    |> Basic.to_qb64_seed()
  end

  @salt_bs 16
  def rnd_salt do
    :enacl.randombytes(@salt_bs)
    |> Basic.to_qb64_salt()
  end

  def to_raw_key(qb46key) do
    cond do
      String.starts_with?(qb46key, ["B", "D"]) ->
        {:ok, Basic.from_qb64(qb46key), Ed.type()}

      true ->
        {:error, "unknown key type"}
    end
  end

  comment("""
            if tier == Tiers.low:
                opslimit = pysodium.crypto_pwhash_OPSLIMIT_INTERACTIVE
                memlimit = pysodium.crypto_pwhash_MEMLIMIT_INTERACTIVE
            elif tier == Tiers.med:
                opslimit = pysodium.crypto_pwhash_OPSLIMIT_MODERATE
                memlimit = pysodium.crypto_pwhash_MEMLIMIT_MODERATE
            elif tier == Tiers.high:
                opslimit = pysodium.crypto_pwhash_OPSLIMIT_SENSITIVE
                memlimit = pysodium.crypto_pwhash_MEMLIMIT_SENSITIVE

  """)

  @seed_tiers %{low: :interactive, med: :moderate, high: :sensitive}

  @key_def_opts %{pidx: 0, kidx: 0, ridx: 0, tier: :low, nt: false, der_code: Ed.type()}
  @doc """
             returns a list of Crypto.Signer structs
             opts:
               pidx: def 0, is int prefix index for key pair sequence
               ridx: def 0, is int rotation index for key pair set
               kidx: def 0, is int starting key index for key pair set
               tier: def :low, is salt stretching strength
               nt: def false, create a non-transferable signer
               der_code: def :ed25519, which crypto algorithm to use


            Notes
              :ed25519 is the only supported code for now
              pidx should be inc'ed for each inception
              kidx should be a continuous sequence, keripy's kli keeps track of the starting kidx
               for each new inception and rotation.
              ridx is inc'ed for each rotation, should be stored
              storing initial pidx,kidx,ridx ensures deterministic reply/recovery from a seed
  """
  def salt_to_signers(qb64salt, count , opts \\ %{}) do
    opts =
      if map_size(opts) == 0 do
        @key_def_opts
      else
        Map.merge(@key_def_opts, opts)
      end

    raw_salt = Basic.from_qb64(qb64salt)

    signers =
      for i <- 0..(count - 1), into: [] do
        # path "{}{:x}{:x}".format(stem, ridx, kidx + i), stem is pidx, hex
        path = :io_lib.format("~.16b~.16b~.16b", [opts.pidx, opts.ridx, opts.kidx + i])

        kp =
          salt_to_seed(raw_salt, path, opts.tier)
          |> Ed.new_keypair()

        {:ok, qb64} =
          if opts.nt do
            kp.public |> Basic.to_qb64_ed_nt_pre()
          else
            kp.public |> Basic.to_qb64_ed_verkey()
          end

        %Signer{keypair: kp, qb64: qb64}
      end

    {:ok, signers}
  end

  defp salt_to_seed(raw_salt, path, tier) when byte_size(raw_salt) == @salt_bs do
    comment("""
    # stretch algorithm is argon2id
    seed = pysodium.crypto_pwhash(outlen=size,
                                  passwd=path,
                                  salt=self.raw,
                                  opslimit=opslimit,
                                  memlimit=memlimit,
                                  alg=pysodium.crypto_pwhash_ALG_DEFAULT)
    """)

    :enacl.pwhash(path, raw_salt, @seed_tiers[tier], @seed_tiers[tier], :default)
  end

  def verkeys_to_digs(keys) when is_list(keys) do
    for key <- keys, into: [] do
      key |> hash_and_encode!()
    end
  end


  @doc """
    hashes the `data` with Blake3 and encodes to qb64
  """
  def hash_and_encode!(data) do
    data
    |> Blake3.hash()
    |> Basic.to_qb64_blake3_dig()
    |> case do
      {:ok, res} ->
        res

      {:error, reason} ->
        raise ArgumentError, reason
    end
  end
end
