defmodule Watcher.AIDMonitor.ObservationParams do
  @moduledoc """
  structure for storing monitoring parameters for an AID
  """
  defstruct ~w[interval ]a
  @type seconds :: non_neg_integer()
  @type t :: %__MODULE__{interval: seconds()}
end

defmodule Watcher.AIDMonitor do
  @moduledoc false

  alias Watcher.AIDMonitor
  alias Watcher.OOBI.{Resolver, IURL, LogsProcessor}
  alias Watcher.{EventEscrow, KeyStateStore}
  alias Kerilex.KELParser
  alias AIDMonitor.{Store, ObservationParams, WorkerLib}

  def introduce_aid(oobi_url, %ObservationParams{} = params) do
    with {:ok, iurl} <- IURL.new(oobi_url),
         :ok <- do_introduce_aid(iurl) do
      :ok = Store.add_aid(iurl.aid, iurl.url, params)
    end
  end

  defp do_introduce_aid(iurl) do
    with {:ok, kel} <- Resolver.kel(iurl),
         parsed_kel when is_list(parsed_kel) <- KELParser.parse(kel, filter_fn: &WorkerLib.filter_stored_events/4),
         escrow = EventEscrow.new(),
         {:ok, escrow, ksc, _cnt} <- LogsProcessor.process_kel(parsed_kel, escrow) do
      if EventEscrow.empty?(escrow) do
        # witness might return an associated KEL, e.g. for a delegator, which is enough to
        # verify the KEL for the target AID, but it might be behind the KEL we already track.
        # For example, when the same delegator AID has events after anchoring the delegation
        # for the target AID.
        # Outside of a valid superseding recovery, KELs with shorter history should not
        # overwrite the existing key states. We ignore these here.
        KeyStateStore.maybe_update_key_states(ksc, ignore_shorter_kels: true)
      else
        {:error,
         "KEL returned in OOBI response could not be fully processed, has out of order events"}
      end
    end
  end
end
