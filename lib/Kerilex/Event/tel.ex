defmodule Kerilex.Event.Tel do
  @moduledoc """
    supports creation of the TEL (Transaction Event Log) events:
    - vcp
  """

  import Kerilex.Constants
  import Comment
  alias Kerilex.Event
  alias Jason.OrderedObject, as: OO
  alias Kerilex.Crypto

  def vcp(issuer_pre, conf \\ []) do
    {:ok, nonce} = Crypto.rnd_seed()
    vcp_nonce(issuer_pre, conf, nonce)
  end

  def vcp_nonce(issuer_pre, conf, nonce) do
    [
      v: Event.keri_version_str(),
      t: "vcp",
      d: "",
      i: "",
      ii: issuer_pre,
      s: "0",
      c: conf,
      bt: "0",
      b: [],
      n: nonce
    ]
    |> serialize()
  end

  alias Kerilex.Attachment.{SealSourceCouples, SealSourceCouple}
  alias Kerilex.Attachment, as: Att

  def att_seal_source_couple(seq, dig, opts \\ [iodata: true]) do
    {:ok, ssc} = SealSourceCouples.encode([SealSourceCouple.new(seq, dig)])
    #{:ok, att_mat_group} = Kerilex.Attachment.encode(ssc, iodata: true)

    if opts[:iodata] do
      ssc
    else
      ssc |> IO.iodata_to_binary()
    end
  end

  alias Kerilex.Event.Query

  def att_sign_and_add_seal_source_couple(pre, signers, tel_msg, seq, dig, opts \\ [iodata: true]) do
    sig_cesr = Query.sign_group_cesr(pre, signers, tel_msg)
    ssc_cesr = att_seal_source_couple(seq, dig, opts)
    Att.encode([sig_cesr, ssc_cesr])
  end

  defp serialize(msg) do
    msg
    |> Jason.OrderedObject.new()
    |> Event.serialize()
    |> case do
      {:ok, serd_msg, _said} ->
        {:ok, serd_msg}

      {:error, reason} ->
        {:error, "failed to encode '#{Keyword.fetch!(msg, :t)}' msg: #{reason}"}
    end
  end
end
