defmodule Watcher.KeyState.IcpEvent do
  @moduledoc """
  defines inception event map for storing in the Key State Store
  """
  import Kerilex.Constants

  alias Watcher.KeyState.Establishment
  alias Kerilex.Event
  alias Jason.OrderedObject, as: OO
  alias Watcher.KeyStateEvent, as: KSE
  alias Kerilex.Crypto.KeyTally
  alias Watcher.KeyState

  @keys Event.icp_labels()

  const(string_keys, @keys)
  @behaviour KSE
  @behaviour Establishment

  @impl KSE
  def new() do
    Map.from_keys(@keys, nil)
  end

  @impl KSE
  def from_ordered_object(%OO{} = msg_obj, event_module \\ __MODULE__) do
    conversions = %{
      "s" => &KSE.to_number/1,
      "bt" => &KSE.to_number/1,
      "v" => &KSE.keri_version/1
    }

    KSE.to_storage_format(msg_obj, event_module, conversions)
    |> case do
      :error ->
        {:error, "failed to convert ordered object to '#{msg_obj["t"]}' storage format"}

      event ->
        validate_event(event)
    end
  end

  defp validate_event(event) do
    cond do
      event["s"] != 0 ->
        {:error, "'#{event["t"]}' event must have sn=0, got: #{event["s"]}"}

      event["d"] != event["i"] ->
        {:error,
         "said and prefix mismatch, 'd'='#{event["d"]}' and 'i'='#{event["i"]}' , event = '#{inspect(event)}'"}

      true ->
        KSE.validate_sig_ths_counts(event)
    end
  end

  @impl Establishment
  def to_state(icp_event, sig_auth, _prased_event \\ nil, _prev_state \\ nil) do
    case KeyTally.new(icp_event["nt"]) do
      {:ok, next_kt} ->
        {:ok,
         %KeyState{
           s: icp_event["s"],
           d: icp_event["d"],
           fs: DateTime.utc_now() |> DateTime.to_iso8601(),
           k: icp_event["k"],
           kt: sig_auth,
           n: icp_event["n"],
           nt: next_kt,
           b: icp_event["b"],
           bt: icp_event["bt"],
           c: icp_event["c"],
           di: false
         }}

      {:error, msg} ->
        {:error, "failed to create KeyState object from '#{icp_event["t"]}' event, " <> msg}

    end
  end
end
