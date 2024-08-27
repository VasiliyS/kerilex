defmodule Watcher.KeyState do
  @moduledoc """
  helper functions to deal with data comprising key state
  e.g. KEL entries, etc
  """
  alias Kerilex.Crypto.WeightedKeyThreshold
  alias Kerilex.Crypto.KeyThreshold
  alias Watcher.KeyState.{IcpEvent, RotEvent, DipEvent, DrtEvent}
  alias Kerilex.Event
  import Comment

  comment("""
   example of a key state notice response from keripy:

  {
    "v": "KERI10JSON0002fa_",
    "t": "rpy",
    "d": "EJ6BhTwHQtxtcHREUEHQAl-nFHW2aRU1yCSuehAj-XDe",
    "dt": "2023-03-09T17:01:36.116731+00:00",
    "r": "/ksn/BEXBtyNmAdUiEMsPYamGdMq4TEQfmitcFAyUYcY15Im2",
    "a": {
      "v": "KERI10JSON00023f_",
      "i": "EAR1eNUllla9Y7l0ru0btqGrFoWuhLk8BkMWFUMEljUY",
      "s": "9",
      "p": "EOvy3DL_zbs-fnPxkZ_Hj-0WWboGpchazc7oit1XsmBI",
      "d": "EOA70My4MnN9qvMDvMjfUwSbHIlaD7JXQOLVOOnHjzdp",
      "f": "9",
      "dt": "2023-03-09T16:59:32.275438+00:00",
      "et": "rot",
      "kt": "1",
      "k": ["DGk74s2P78p296WsszFZXPYnxc6_gGDWonDeVHpB8BEE"],
      "nt": "1",
      "n": ["EMLgsS5D0rGd7PI1Mn7wARiiY4tXErwCi0jkJ-IZbPdw"],
      "bt": "2",
      "b": [
        "BEXBtyNmAdUiEMsPYamGdMq4TEQfmitcFAyUYcY15Im2",
        "BI7jE8sYGKsMoqzdflooeWrhU0Ecp5XJoY4V4cC-zyQy"
      ],
      "c": [],
      "ee": {
        "s": "9",
        "d": "EOA70My4MnN9qvMDvMjfUwSbHIlaD7JXQOLVOOnHjzdp",
        "br": [],
        "ba": []
      },
      "di": ""
    }
  }

  """)

  @typedoc """
  iso_8601 formatted string representing timestamp
  """
  @type iso8601 :: String.t()

  @typedoc """
  defines KeyState of an `AID`, used to calculate current KeyState during processing of an `OOBI` introduction
  or as updates from a Key Event Log are processed.
  """
  @type t :: %__MODULE__{
          pe: Kerilex.said(),
          te: Kerilex.kel_ilk(),
          se: Kerilex.int_sn(),
          de: Kerilex.said(),
          fs: iso8601(),
          k: [Kerilex.qb64_pub_key(), ...],
          kt: %KeyThreshold{} | %WeightedKeyThreshold{},
          n: [Kerilex.qb64_next_pub_key(), ...],
          nt: %KeyThreshold{} | %WeightedKeyThreshold{},
          b: list(Kerilex.basic_pre()),
          bt: non_neg_integer(),
          c: Kerilex.aid_conf(),
          di: Kerilex.pre(),
          last_event: {Kerilex.kel_ilk(), Kerilex.int_sn(), Kerilex.said()}
        }
  defstruct ~w|pe te se de fs k kt n nt b bt c di last_event|a

  @est_events Event.est_events()

  def new(), do: %__MODULE__{}

  def new(%{"t" => type} = est_event, sig_auth, attachments, %__MODULE__{} = prev_state)
      when type in @est_events do
    to_state(type, est_event, sig_auth, attachments, prev_state)
    |> case do
      {:ok, new_ks} ->
        t = est_event["t"]
        s = est_event["s"]
        d = est_event["d"]

        {:ok,
         %{
           new_ks
           | pe: est_event["p"],
             te: t,
             se: s,
             de: d,
             last_event: {t, s, d}
         }}

      err ->
        err
    end
  end

  # non establishment events don't change key state, but add their info to the state
  def new(event, _attachments, _sig_auth, prev_state) do
    {:ok, %{prev_state | last_event: {event["t"], event["s"], event["d"]}}}
  end

  defp to_state("icp", icp_event, sig_auth, _attachments, prev_state) do
    IcpEvent.to_state(icp_event, sig_auth, prev_state)
  end

  defp to_state("dip", rot_event, sig_auth, _attachments, prev_state) do
    DipEvent.to_state(rot_event, sig_auth, prev_state)
  end

  defp to_state("rot", rot_event, sig_auth, attachments, prev_state) do
    RotEvent.to_state(rot_event, sig_auth, attachments, prev_state)
  end

  defp to_state("drt", rot_event, sig_auth, attachments, prev_state) do
    DrtEvent.to_state(rot_event, sig_auth, attachments, prev_state)
  end

  defp to_state(type, _ee, _sig_auth, _atts, _prev_state) do
    {:error, "establishment event type: '#{type}' is not implemented"}
  end

  ######################## threshold checking

  def check_backer_threshold(%__MODULE__{} = ks, indices) do
    if length(indices) < ks.bt do
      {:error,
       "number of backers sigs (#{length(indices)}) is lower than the required threshold: #{ks.bt}"}
    else
      :ok
    end
  end

  def check_ctrl_sigs(%__MODULE__{} = ks, serd_msg, ctrl_sigs) do
    check_idx_sigs(ks, serd_msg, ctrl_sigs, :k)
    |> case do
      {:error, reason} ->
        {:error, "controller signature check failed:" <> reason}

      res ->
        res
    end
  end

  defp check_idx_sigs(ks, serd_msg, idx_sigs, key) do
    with {:ok, verkey_lst} <- Map.fetch(ks, key) do
      verkey_lst |> validate_idx_sigs(idx_sigs, serd_msg)
    end
  end

  defp validate_idx_sigs([], _idx_sigs, _data), do: {:error, "msg has an empty key list"}

  defp validate_idx_sigs(key_lst, idx_sigs, data) do
    nok = length(key_lst)

    idx_sigs
    |> Enum.reduce_while(
      _acc = {:ok, []},
      fn sig, {:ok, indices} ->
        validate_idx_sig(nok, key_lst, sig, data)
        |> case do
          :ok ->
            %{ind: sind} = sig
            {:cont, {:ok, [sind | indices]}}

          error ->
            {:halt, error}
        end
      end
    )
  end

  alias Kerilex.Attachment.Signature, as: Sig

  defp validate_idx_sig(no_keys, key_lst, %{sig: sig, ind: sind}, data) do
    if sind > no_keys do
      {:error, "sig ind error: got: #{sind}, total keys: #{no_keys}"}
    else
      key_qb64 = key_lst |> Enum.at(sind)
      Sig.check_with_qb64key(sig, data, key_qb64)
    end
  end

  # @compile {:inline, wrap_error: 2}
  # defp wrap_error(term, msg)

  # defp wrap_error(:error, msg) do
  #   {:error, msg}
  # end

  # defp wrap_error(term, _), do: term
end
