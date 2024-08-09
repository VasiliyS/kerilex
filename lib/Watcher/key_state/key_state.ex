defmodule Watcher.KeyState do
  @moduledoc """
  helper functions to deal with data comprising key state
  e.g. KEL entries, etc
  """
  alias Kerilex.Crypto.WeightedKeyThreshold
  alias Kerilex.Crypto.KeyThreshold
  alias Watcher.KeyState.{IcpEvent, RotEvent, DipEvent}
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
  defines KeyState of an `AID`, used to calculate current KeyState during processing of an `OOBI` introduction
  or as updates from a Key Event Log are processed.
  """
  @type t :: %__MODULE__{
          p: String.t(),
          s: non_neg_integer(),
          d: String.t(),
          fs: String.t(),
          k: list(String.t()),
          kt: %KeyThreshold{} | %WeightedKeyThreshold{},
          n: list(String.t()),
          nt: %KeyThreshold{} | %WeightedKeyThreshold{},
          b: list(String.t()),
          bt: non_neg_integer(),
          c: list(String.t()),
          di: Kerilex.pre()
        }
  defstruct ~w|p s d fs k kt n nt b bt c di|a

  @est_events Event.est_events()

  def new(), do: %__MODULE__{}

  def new(%{"t" => type} = est_event, sig_auth, attachments, prev_state)
      when type in @est_events do
    to_state(type, est_event, sig_auth, attachments, prev_state)
  end

  # non establishment events don't change key state
  def new(_event, _attachments, prev_state) do
    {:ok, prev_state}
  end

  defp to_state("icp", icp_event, sig_auth, _attachments, _prev_state) do
    IcpEvent.to_state(icp_event, sig_auth)
  end

  defp to_state("dip", rot_event, sig_auth, _attachments, _prev_state) do
    DipEvent.to_state(rot_event, sig_auth)
  end

  defp to_state("rot", rot_event, sig_auth, attachments, %__MODULE__{} = prev_state) do
    RotEvent.to_state(rot_event, sig_auth, attachments, prev_state)
  end

  defp to_state(type, _ee, _sig_auth, _atts, _prev_state) do
    {:error, "establishment event type: '#{type}' is not implemented"}
  end
end
