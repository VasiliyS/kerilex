defmodule Kerilex.Event do
  @moduledoc """
  common event creation logic

  """
  import Kerilex.Constants
  alias Kerilex.Crypto
  alias Jason.OrderedObject, as: OO

  @said_ph Kerilex.said_placeholder(44)
  @saidify_labels %{"icp" => [:d, :i], "dip" => [:d, :i], "vcp" => [:d, :i]}
  @keri_ver "KERI10"

  # inception labels
  @icp_labels ["v", "d", "i", "s", "t", "kt", "k", "nt" ,"n", "bt", "b", "c", "a"]

  # delegated inception labels
  @dip_labels ["v", "i", "s", "t", "kt", "k", "nt", "n", "bt", "b", "c", "a", "di"]

  # rotation labels
  @rot_labels ["v", "i", "s", "t", "p", "kt", "k", "nt", "n", "bt", "br", "ba", "a"]

  # delegated rotation labels
  @drt_labels ["v", "i", "s", "t", "p", "kt", "k", "nt", "n", "bt", "br", "ba", "a"]

  # interaction event labels
  @ixn_labels ["v", "i", "s", "t", "p", "a"]

  # key state notice labels
  @ksn_labels [
    "v",
    "i",
    "s",
    "p",
    "d",
    "f",
    "dt",
    "et",
    "kt",
    "k",
    "n",
    "bt",
    "b",
    "c",
    "ee",
    "di"
  ]

  # reply event labels
  @rpy_labels ["v", "t", "d", "dt", "r", "a"]

  @vcp_labels ~w[v t d i ii s c bt b n]

  @known_event_types %{
    "icp" => @icp_labels,
    "dip" => @dip_labels,
    "rot" => @rot_labels,
    "drt" => @drt_labels,
    "ixn" => @ixn_labels,
    "ksn" => @ksn_labels,
    "rpy" => @rpy_labels,
    "vcp" => @vcp_labels
  }

  const(keri_version_str, @keri_ver <> "JSON000000_")
  const(icp_labels, @icp_labels)
  const(dip_labels, @dip_labels)
  const(rot_labels, @rot_labels)
  const(drt_labels, @drt_labels)
  const(ixn_labels, @ixn_labels)
  const(ksn_labels, @ksn_labels)
  const(rpy_labels, @rpy_labels)
  const(vcp_labels, @vcp_labels)

  @est_events ~w[icp dip rot drt]
  const(est_events, @est_events)

  @doc """
  returns a list of the labels that the event type should have
  """
  def get_labels(%OO{} = event) do
    if type = event["t"] do
      case Map.fetch(@known_event_types, type) do
        :error ->
          {:error, "event has unknown type '#{inspect(type)}'"}

        res ->
          res
      end
    else
      {:error, "event has no type"}
    end
  end

  @doc """
  Takes parsed KERI event as `Jason.OrderedObject` and ensures that all the labels (or field names)
  as required by the event's type are present.

  Returns `:ok` or `{:error, reason}`
  """
  def check_labels(%OO{} = event) do
    event
    |> get_labels()
    |> case do
      {:ok, labels} ->
        labels
        |> Enum.reduce_while(
          false,
          fn l, _res ->
            if event[l] != nil, do: {:cont, true}, else: {:halt, {:missing_label, l}}
          end
        )

      error ->
        error
    end
    |> case do
      true ->
        :ok

      {:missing_label, l} ->
        {:error, "event has no label '#{l}'"}

      error ->
        error
    end
  end

 @doc """
 Helper function. Will check if the given `event_type` is allowed by the `conf`.

 `conf` is an array with the configuration's data, e.g. `["DND", "EO", "NB"]`.

  - "DND" - no delegation
  - "EO" - establishment only events, i.e no 'ixn', etc.
  - "NB" - no backers for the registry (ACDC related)

 it's contained in the `"c"` field of the `icp` or `dip` event.

 """
  def is_event_allowed?(conf, event_type) when is_list(conf) do
    cond do
      conf == [] ->
        true

      event_type == "dip" and "DND" in conf ->
        false

      event_type in ["rot", "drt"] and "EO" in conf ->
        true

      "EO" in conf ->
        false

      true ->
        true
    end
  end

  @doc """
  Returns json of the event as a string. Calculates and places `said` of the event into the defined labels.

  e.g. for `icp` event "i" and "d" will be replaced with the `said` of the event.
  """
  def serialize(%OO{} = event) do
    with type when type != nil <- event[:t],
         {:ok, said, prepped_event} <- event |> marshall(type) do
      {:ok,
       prepped_event
       |> String.replace(@said_ph, said), said}
    else
      nil ->
        {:error, "malformed KERI event, no type ('t') specified"}

      {:error, reason} ->
        {:error, "failed to serialize the event: #{reason}"}
    end
  end

  defp marshall(event, type) do
    type =
      if type == "icp" do
        adjust_for_backer_icp(event)
      else
        type
      end

    @saidify_labels
    |> Map.fetch(type)
    |> case do
      {:ok, ll} ->
        ll

      _ ->
        [:d]
    end
    |> saidify(event)
  end

  # special logic for inception events that are done for witnesses/backers
  # they are using non-transferable prefix and so "i" has to be the same as the key
  defp adjust_for_backer_icp(event) do
    if event[:i] != "", do: "_icp", else: event[:t]
  end

  defp saidify(labels_to_replace, event) do
    # replace all labels for hash calculation
    # ( e.d. 'd' for digest, 'i' for prefix in icp event, etc)

    # TODO(VS): can I re-use some of the logic from the parser?

    with {:ok, prepped_event} <-
           labels_to_replace |> saidify_labels(event),
         {:ok, enc_event} <- Jason.encode(prepped_event) do
      enc_event = enc_event |> calc_and_update_size()
      said = enc_event |> Crypto.hash_and_encode!()
      {:ok, said, enc_event}
    end
  end

  defp calc_and_update_size(enc_event) do
    enc_event
    |> byte_size()
    |> int_to_hex()
    |> String.pad_leading(6, "0")
    |> then(&String.replace(enc_event, ~r/000000/, &1, global: false))
  end

  defp saidify_labels(labels, event) do
    labels
    |> Enum.reduce_while(
      {:ok, event},
      fn label, {:ok, event} ->
        put_said_placeholder(label, event)
        |> case do
          {:ok, _} = res ->
            {:cont, res}

          error ->
            {:halt, error}
        end
      end
    )
  end

  defp put_said_placeholder(label, event) do
    event
    |> OO.get_and_update(
      label,
      fn val ->
        new_val = if val != nil, do: @said_ph, else: :pop
        {val, new_val}
      end
    )
    |> case do
      {nil, _} ->
        {:error, "event has no label '#{Atom.to_string(label)}'"}

      {_, prepd_event} ->
        {:ok, prepd_event}
    end
  end

  @doc """
    converts integer to a lower case hex
  """
  def int_to_hex(number) do
    number |> Integer.to_string(16) |> String.downcase()
  end


end
