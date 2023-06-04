defmodule Watcher.KeyState do
  @moduledoc """
  helper functions to deal with data comprising key state
  e.g. KEL entries, etc
  """
  alias Kerilex.Event
  import Comment

  comment("""
   example of a key state notice response form keripy:

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

  @est_events Event.est_events()

  def new(%{"t" => type} = est_event) when type in @est_events do
    to_state(type, est_event)
  end

  def new(event) do
    {:error, "wrong event type, expected one of: #{inspect(@est_events)}, got: '#{event["t"]}'"}
  end

  @icp_filter_labels  ~w|v i d|
  defp to_state("icp", icp_event) do
    {:ok, icp_event}
  end

  defp to_state(type, _ee) do
    {:error, "establishment event type: '#{type}' is not implemented"}
  end
end
