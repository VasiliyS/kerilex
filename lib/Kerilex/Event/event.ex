defmodule Kerilex.Event do
  @moduledoc """
  common event creation logic

  """
  import Kerilex.Constants

  @said_ph Kerilex.said_placeholder(44)

  const keri_version_str, "KERI10JSON000000_"

  def serialize(%Jason.OrderedObject{} = event) do
    {said, prepped_event} = get_said(event) |> IO.inspect

    prepped_event
    |> String.replace(@said_ph, said)
  end

  defp keri_event_size(ser_event) do
    1
  end

  def get_said(event, opts \\ [placeholders: ["d"]]) do
    # replace all labels for hash calculation
    # ( e.d. 'd' for digest, 'i' for prefix in icp event, etc)
    labels_to_replace = Keyword.get(opts, :placeholders)

    prepped_event =
      Enum.reduce(
        labels_to_replace,
        event,
        &put_said_placeholder/2
      )
      |> Jason.encode!()

    size_str =
      prepped_event
      |> byte_size()
      |> Integer.to_string(16)
      |> String.downcase()
      |> String.pad_leading(6, "0")

    prepped_event =
      prepped_event
      |> String.replace(~r/N000000_/, "N" <> size_str <> "_", global: false)

    said =
      prepped_event
      |> Blake3.hash()
      |> then(&Kernel.<>(<<0>>, &1))
      |> Base.url_encode64(padding: false)
      |> binary_part(1, 43)
      |> then(&Kernel.<>(<<"E">>, &1))

    {said, prepped_event}
  end

  defp put_said_placeholder(label, event) do
    event
    |> Access.get_and_update(
      String.to_atom(label),
      fn val ->
        new_val = if val != nil, do: Kerilex.said_placeholder(44), else: nil
        {val, new_val}
      end
    )
    |> then(fn {_nv, updt_evnt} -> updt_evnt end)
  end



end
