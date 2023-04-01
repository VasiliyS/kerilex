defmodule Watcher.Controller do
  defstruct pre: nil, signer: nil, nsigner: nil, backers: [], inception: nil

  alias Kerilex.Event.Inception, as: Icp
  alias Kerilex.Crypto
  alias Kerilex.Attachment.IndexedControllerSigs, as: ICSigs
  alias Kerilex.Attachment.IndexedWitnessSigs, as: IWSigs
  alias Kerilex.Attachment, as: Att

  def new(salt) do

    {:ok, [signer]} = Crypto.salt_to_signers(salt, 1)
    next_key_opts = %{ridx: 1, kidx: 1}
    {:ok, [nsigner]} = Crypto.salt_to_signers(salt, 1, next_key_opts)
    {:ok, backer} = Crypto.salt_to_signers(salt, 1, %{pidx: 1, nt: true})
    {:ok, ctrl} = incept(%__MODULE__{signer: signer, nsigner: nsigner, backers: backer})
    {:ok, att} = sign_icp(ctrl)

    %__MODULE__{ctrl | inception: %{serd_event: ctrl.inception, att: att}}

  end

  def incept(%__MODULE__{} = ctrl) do
    verkey = ctrl.signer.qb64
    kt = "1"

    nts = kt
    ndigs =  [ctrl.nsigner.qb64] |> Crypto.verkeys_to_digs()

    backers =
      for b <- ctrl.backers, into: [] do
        b.qb64
      end
    {:ok, serd_event, pre} = Icp.event([kt], [verkey], [nts], ndigs, backers)

    {:ok, %__MODULE__{ctrl | pre: pre, inception: serd_event}}
  end

  defp sign_icp(%{signer: signer, backers: backers, inception: icp_msg}) do

    {:ok, ctrl_sig } = Crypto.Signer.sign(signer, icp_msg)
    ctrl_sig = %Att.IndexedControllerSig{sig: ctrl_sig, ind: 0}


    wit_sigs =
    for {b, ind} <- Enum.with_index(backers), into: [] do
      {:ok, sig} = Crypto.Signer.sign(b, icp_msg)
      %Att.IndexedWitnessSig{sig: sig, ind: ind}
    end

    {:ok, idx_ctrl_sig} = [ctrl_sig] |> ICSigs.encode()
    {:ok, idx_wit_sigs} = wit_sigs |> IWSigs.encode()

    Att.encode([idx_ctrl_sig, idx_wit_sigs])

  end
end
