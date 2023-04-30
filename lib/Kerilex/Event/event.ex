defmodule Kerilex.Event do
  @moduledoc """
  common event creation logic

  """
  import Kerilex.Constants
  alias Kerilex.Crypto
  alias Jason.OrderedObject, as: OO

  @said_ph Kerilex.said_placeholder(44)
  @saidify_labels %{"icp" => [:d, :i], "dip" => [:d, :i]}
  @keri_ver "KERI10"

  const(keri_version_str, @keri_ver <> "JSON000000_")

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
           labels_to_replace |> saidify_labels(event) ,
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
