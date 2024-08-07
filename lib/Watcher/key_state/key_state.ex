defmodule Watcher.KeyState do
  @moduledoc """
  helper functions to deal with data comprising key state
  e.g. KEL entries, etc
  """
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

  defstruct ~w|p s d fs k kt n nt b bt c di|a

  @est_events Event.est_events()

  def new(), do: %__MODULE__{}

  def new(%{"t" => type} = est_event, attachments, prev_state) when type in @est_events do
    to_state(type, est_event, attachments, prev_state)
  end

  # non establishment events don't change key state
  def new(_event, _attachments, prev_state) do
    {:ok, prev_state}
  end

  defp to_state("icp", icp_event, _attachments, _prev_state) do
    {:ok,
     %__MODULE__{
       p: icp_event["p"],
       s: icp_event["s"],
       d: icp_event["d"],
      #  dt: icp_event["dt"],
       fs: DateTime.utc_now() |> DateTime.to_iso8601(),
       k: icp_event["k"],
       kt: icp_event["kt"],
       n: icp_event["n"],
       nt: icp_event["nt"],
       b: icp_event["b"],
       bt: icp_event["bt"],
       c: icp_event["c"]
     }}
  end

  alias Watcher.KeyState.RotEvent

  defp to_state("rot", rot_event, attachments, %__MODULE__{} = prev_state) do

    comment("""
    `rot` can do the following:
     1. use keys from the "n" list (either `icp` or updated through a prev `rot` )
     2. add and delete witnesses
     3. anchor a "seal", e.g. digest/said ("d") + sn ("s") + identifier ("i") of a `dip` or a tel event

     1 and 2 will be validated and calculated here

     3 will be handled by the storage (as part of the OOBI/KEL stream processing),
     which will simply take `a` field and store it in the db.
    """)

    :ok = RotEvent.validate_new_keys(prev_state, rot_event, attachments)
    {:ok, b } = RotEvent.new_backers(prev_state.b, rot_event["ba"], rot_event["br"], rot_event["bt"])


    {:ok,
     %__MODULE__{
       p: rot_event["p"],
       s: rot_event["s"],
       d: rot_event["d"],
      #  dt: rot_event["dt"],
       fs: DateTime.utc_now() |> DateTime.to_iso8601(),
       k: rot_event["k"],
       kt: rot_event["kt"],
       n: rot_event["n"],
       nt: rot_event["nt"],
       b: b,
       bt: rot_event["bt"]
     }}
  end

  defp to_state(type, _ee, _atts, _prev_state) do
    {:error, "establishment event type: '#{type}' is not implemented"}
  end
end
