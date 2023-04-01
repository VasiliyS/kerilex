defmodule Kerilex.Event do
  @moduledoc """
  common event creation logic

  """
  import Kerilex.Constants
  alias Kerilex.Derivation.Basic
  alias Kerilex.Crypto
  alias Jason.OrderedObject, as: OO

  @said_ph Kerilex.said_placeholder(44)
  @saidify_labels %{"icp" => ["d", "i"], "dip" => ["d", "i"]}
  @keri_ver "KERI10"

  const(keri_version_str, @keri_ver <> "JSON000000_")




  def serialize(%OO{} = event) do

    {said, prepped_event} =
      event[:t]
      |> marshall(event)

  {:ok,
    prepped_event
    |> String.replace(@said_ph, said),
    said}
  end

  defp marshall(type, %OO{} = pmsg) do
    @saidify_labels
    |> Map.fetch(type)
    |> case do
      {:ok, ll} ->
        ll

      _ ->
        ["d"]
    end
    |> then(&saidify(pmsg, placeholders: &1))
  end


  defp saidify(event, opts ) do
    # replace all labels for hash calculation
    # ( e.d. 'd' for digest, 'i' for prefix in icp event, etc)
    labels_to_replace = Keyword.get(opts, :placeholders)

    prepped_event = #TODO(VS): reuse saidify logic from KEL module.
      Enum.reduce(
        labels_to_replace,
        event,
        &put_said_placeholder/2
      )
      |> Jason.encode!()

    size_str =
      prepped_event
      |> byte_size()
      |> int_to_hex()
      |> String.pad_leading(6, "0")

    prepped_event =
      prepped_event
      |> String.replace(~r/N000000_/, "N" <> size_str <> "_", global: false)

    said =
      prepped_event
      |> Crypto.hash_and_encode!()

    {said, prepped_event}
  end

  defp put_said_placeholder(label, event) do
    event
    |> OO.get_and_update(
      String.to_atom(label),
      fn val ->
        new_val = if val != nil, do: @said_ph, else: :pop
        {val, new_val}
      end
    )
    |> then(fn {_nv, updt_evnt} -> updt_evnt end)
  end

  @doc """
    converts integer to a lower case hex
  """
  def int_to_hex(number) do
    number |> Integer.to_string(16) |> String.downcase()
  end

end
