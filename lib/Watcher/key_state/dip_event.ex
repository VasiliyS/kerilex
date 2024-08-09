defmodule Watcher.KeyState.DipEvent do
  @moduledoc """
  defines delegated inception (`dip`) event map for storing in the Key State Store
  """
  @keys Kerilex.Event.dip_labels()

  import Kerilex.Constants
  import Comment

  comment("""
    {
    "v": "KERI10JSON0003f9_",
    "t": "dip",
    "d": "EINmHd5g7iV-UldkkkKyBIH052bIyxZNBn9pq-zNrYoS",
    "i": "EINmHd5g7iV-UldkkkKyBIH052bIyxZNBn9pq-zNrYoS",
    "s": "0",
    "kt": [
      "1/2",
      "1/2",
      "1/2",
      "1/2",
      "1/2"
    ],
    "k": [
      "DEO7QT90CzPeCubjcAgDlYI-yudt0c_4HeAb1_RbrGiF",
      "DKu6Q_Qth7x-pztt11qXDr42B9aUjkp_v9Rq8-xXcQjF",
      "DEiPSxcuILZFxJscr_Lt8fuiidhB_HrqKxoCbZr9tQfp",
      "DIqrjqqwArsSHIX3n510DnSrYL9ULbYOpi14hEencBSC",
      "DAB9Tl0T8-638H65GMFj2G7CAr4CoExZ5xH-U1ADldFP"
    ],
    "nt": [
      "1/2",
      "1/2",
      "1/2",
      "1/2",
      "1/2"
    ],
    "n": [
      "EObLskWwczY3R-ALRPWiyyThtraelnbh6MMeJ_WcR3Gd",
      "ENoI2e5f59xEF83joX__915Va-OIE7480wWyh2-8bJk7",
      "EElSAVDf2vU8aoxN50eSMNm6MrQ-Hv_2xOWC02tFrS3M",
      "EHX0Re-hExzl7mvLuRwQHEew-8oPOQh4rqXJNHBo9EyW",
      "EBGeYe1_ZgN_ly0qVY-Y1FayZkNA5Yq9LTujrh2ylKbm"
    ],
    "bt": "4",
    "b": [
      "BDkq35LUU63xnFmfhljYYRY0ymkCg7goyeCxN30tsvmS",
      "BLmvLSt1mDShWS67aJNP4gBVBhtOc3YEu8SytqVSsyfw",
      "BHxz8CDS_mNxAhAxQe1qxdEIzS625HoYgEMgqjZH_g2X",
      "BGYJwPAzjyJgsipO7GY9ZsBTeoUJrdzjI2w_5N-Nl6gG",
      "BFl6k3UznzmEVuMpBOtUUiR2RO2NZkR3mKrZkNRaZedo"
    ],
    "c": [],
    "a": [],
    "di": "EDP1vHcw_wc4M__Fj53-cJaBnZZASd-aMTaSyWEQ-PC2"
    }
  """)

  const(keys, @keys)

  def new do
    Map.from_keys(@keys, nil)
  end

  alias Watcher.KeyStateEvent, as: KSE
  alias Kerilex.Crypto.KeyTally
  alias Watcher.KeyState
  alias Jason.OrderedObject, as: OO

  def to_state(dip_event, sig_auth) do
    case KeyTally.new(dip_event["nt"]) do
      {:ok, next_kt} ->
        {:ok,
         %KeyState{
           s: dip_event["s"],
           d: dip_event["d"],
           fs: DateTime.utc_now() |> DateTime.to_iso8601(),
           k: dip_event["k"],
           kt: sig_auth,
           n: dip_event["n"],
           nt: next_kt,
           b: dip_event["b"],
           bt: dip_event["bt"],
           c: dip_event["c"],
           di: dip_event["di"]
         }}

      {:error, msg} ->
        {:error, "failed to create KeyState object from 'dip' event, " <> msg}
    end
  end

  def from_ordered_object(%OO{} = msg_obj) do
    conversions = %{
      "s" => &KSE.to_number/1,
      "bt" => &KSE.to_number/1,
      "v" => &KSE.keri_version/1
    }

    KSE.to_storage_format(msg_obj, Watcher.KeyState.DipEvent, conversions)
    |> case do
      :error ->
        {:error, "failed to convert ordered object to 'dip' storage format"}

      dip ->
        validate_event(dip)
    end
  end

  defp validate_event(dip) do
    cond do
      dip["s"] != 0 ->
        {:error, "dip event must have sn=0, got: #{dip["s"]}"}

      dip["d"] != dip["i"] ->
        {:error,
         "said and prefix mismatch, 'd'='#{dip["d"]}' and 'i'='#{dip["i"]}' , dip = '#{inspect(dip)}'"}

      dip["di"] == "" or dip["di"] == nil ->
        {:error, "'di' field empty or missing, dip = '#{inspect(dip)}'"}

      true ->
        KSE.validate_sig_ths_counts(dip)
    end
  end

  @doc """
  construct a seal %{d, i, s} from a delegated event
  """
  def seal(%{} = dip_event) do
    %{
      "d" => dip_event["d"],
      "i" => dip_event["i"],
      "s" => dip_event["s"]
    }
  end
end
