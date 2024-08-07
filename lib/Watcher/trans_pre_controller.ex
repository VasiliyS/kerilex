defmodule Watcher.TransPreController do
  defstruct pre: nil, signer: nil, nsigner: nil, inception: nil

  alias Kerilex.Event.Inception, as: Icp
  alias Kerilex.Crypto
  alias Kerilex.Attachment.IndexedControllerSigs, as: ICSigs
  alias Kerilex.Attachment, as: Att

  def new(salt, stem \\ "") do
    opts =
      if stem != "" do
        %{stem: stem}
      else
        %{stem: "__signatory__"}
      end

    {:ok, [signer]} = Crypto.salt_to_signers(salt, 1, opts)
    next_key_opts = Map.merge(opts, %{ridx: 1, kidx: 1})
    {:ok, [nsigner]} = Crypto.salt_to_signers(salt, 1, next_key_opts)
    # {:ok, ctrl} = incept(%__MODULE__{signer: signer, nsigner: nsigner})
    # {:ok, att} = sign_icp(ctrl)

    # %__MODULE__{ctrl | inception: %{serd_event: ctrl.inception, att: att}}
    %__MODULE__{signer: signer, nsigner: nsigner}
  end

  def incept_for(%__MODULE__{} = ctrl, backer_pre) do
    verkey = ctrl.signer.qb64
    kt = "1"

    nts = kt
    ndigs = [ctrl.nsigner.qb64] |> Crypto.verkeys_to_digs()

    {:ok, serd_event, pre} = Icp.encode([kt], [verkey], [nts], ndigs, [backer_pre])

    {:ok, att} = sign_icp(ctrl, serd_event)
    {:ok, %__MODULE__{ctrl | pre: pre, inception: %{serd_event: serd_event, att: att}}}
  end

  def icp_data(%__MODULE__{} = ctrl) do
    {ctrl.inception.serd_event, ctrl.inception.att}
  end

  def pre_and_signer(%__MODULE__{} = ctrl) do
    {ctrl.pre, ctrl.signer}
  end

  defp sign_icp(%{signer: signer}, icp_msg) do
    {:ok, ctrl_sig} = Crypto.Signer.sign(signer, icp_msg)
    ctrl_sig = %Att.IndexedControllerSig{sig: ctrl_sig, ind: 0}

    {:ok, idx_ctrl_sig} = [ctrl_sig] |> ICSigs.encode()

    Att.encode(idx_ctrl_sig)
  end
end
