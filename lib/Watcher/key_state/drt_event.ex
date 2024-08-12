defmodule Watcher.KeyState.DrtEvent do
  @moduledoc """
  defines delegated rotation (`drt`) event map for storing in the Key State Store
  """
  import Comment

  comment("""
            {
            "v": "KERI10JSON000160_",
            "t": "drt",
            "d": "EM5fj7YtOQYH3iLyWJr6HZVVxrY5t46LRL2vkNpdnPi0",
            "i": "EHng2fV42DdKb5TLMIs6bbjFkPNmIdQ5mSFn6BTnySJj",
            "s": "1",
            "p": "EHng2fV42DdKb5TLMIs6bbjFkPNmIdQ5mSFn6BTnySJj",
            "kt": "1",
            "k": [
              "DE3-kGVqHrdeeKPcL83jLjYS0Ea_CWgFHogusIwf-P9P"
            ],
            "nt": "1",
            "n": [
              "EMj2mWvNvn6w9BbGUADX1AU3vn7idcUffZIaCvAsibru"
            ],
            "bt": "0",
            "br": [],
            "ba": [],
            "a": []
            }

            CESR att:
            -A AB <- indexed Ctrl sigs
              A
               AB
                _x-9_FTWr-OW_xXBN5pUkFNqLpAqTTQC02sPysnP0WmBFHb8NWvog9F-o279AfpPcLMxktypg1Fz7EQFYCuwC
              -G AB - Seal Source Couples
                0AAAAAAAAAAAAAAAAAAAAAAC
                EJaPTWDiWvay8voiJkbxkvoabuUf_1a22yk9tVdRiMVs

  """)

  import Kerilex.Constants

  alias Watcher.KeyState.Establishment
  alias Watcher.KeyStateEvent
  alias Watcher.KeyState.RotEvent

  @behaviour KeyStateEvent
  @behaviour Watcher.KeyState.Establishment

  @keys Kerilex.Event.drt_labels()
  const(keys, @keys)


  @impl true
  def new do
    Map.from_keys(@keys, nil)
  end

  @impl true
  defdelegate from_ordered_object(msg_obj, event_module \\ __MODULE__), to: RotEvent

  @impl Establishment
  defdelegate to_state(rot_event, sig_auth, attachments, prev_state), to: RotEvent
end
