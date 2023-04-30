defmodule Watcher.NonTransController do
  @moduledoc """
    attempt to define a controller that can introduce itself to a witness but is using
    a non-trans prefix. The idea is to avoid depending on a witness

    Result: doesn't work: `icp` is accepted, query is then accepted ( using -H counter code for the sig, att)
    but witness can't respond, it checks to see if teh requesting pre belongs to it. However, `icp` event from a non-trans prefix is not logged, so
    it can't find it. (error: "exiting because can't find wit for: B...)
  """
  defstruct pre: nil, signer: nil, inception: nil

  alias Kerilex.Event.Inception, as: Icp
  alias Kerilex.Crypto
  alias Kerilex.Attachment.IndexedControllerSigs, as: ICSigs
  alias Kerilex.Attachment, as: Att

  def new(salt) do
    {:ok, [signer]} = Crypto.salt_to_signers(salt, 1, %{nt: true})
    {:ok, ctrl} = incept(%__MODULE__{signer: signer})
    {:ok, att} = sign_icp(ctrl)

    %__MODULE__{ctrl | inception: %{serd_event: ctrl.inception, att: att}}
  end

  def incept(%__MODULE__{} = ctrl) do
    verkey = ctrl.signer.qb64

    {:ok, serd_event, _said} = Icp.encode(verkey)

    {:ok, %__MODULE__{ctrl | pre: verkey, inception: serd_event}}
  end

  defp sign_icp(%{signer: signer, inception: icp_msg}) do
    {:ok, ctrl_sig} = Crypto.Signer.sign(signer, icp_msg)

    # witnesses generate icp event with the following CESR sign (ex)
    # -AABAAA4r2kRR7Ex5m7mDY-bqnQD4HFKCk-ouKdd_5OzJeLp-jDXgiHo5F4tHaBh-S45JK-kHxMViqHai_pVS-0gOP0I
    ctrl_sig = %Att.IndexedControllerSig{sig: ctrl_sig, ind: 0}

    {:ok, idx_ctrl_sigs} = [ctrl_sig] |> ICSigs.encode()

    Att.encode([idx_ctrl_sigs])
  end
end
