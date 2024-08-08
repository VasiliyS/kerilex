defmodule Watcher.KeyStateEvent do
  @moduledoc """
  Utility functions for converting `Jason.OrderedObject` to maps for storage in the Key State Store
  """

  alias Jason.OrderedObject, as: OO
  alias Watcher.KeyState.Seal

  @doc """
  check that counts (lengths) of keys and thresholds are the same
  should be used for the establishment events (e.g. `icp`, `rot`, `dip`, `drt`)
  """
  def validate_sig_ths_counts(est_event) do
    kl = length(est_event["k"])
    ktl = length(est_event["kt"])
    nl = length(est_event["n"])
    ntl = length(est_event["nt"])

    cond do
    kl != ktl ->
      {:error,
       "establishment event has mismatching signing authority configuration, count of 'k'(#{kl}) != count of 'kt'(#{ktl})"}
    nl != ntl ->
      {:error,
       "establishment event has mismatching next key configuration, count of 'n'(#{nl}) != count of 'nt'(#{ntl})"}
    true ->
      {:ok, est_event}
    end
  end

  @doc """
  takes the value of the "v" field and returns just the KERI version string. e.g. "KERI10".
  """
  def keri_version(<<version::binary-size(6), _::bitstring>>), do: {:ok, version}
  def keri_version(_data), do: {:error, "badly formed KERI version field"}

  @doc """
  converts `Jason.OrderedObject` to the data structure suitable for Key State Storage
  """
  def to_storage_format(%OO{} = msg_obj, module, field_mapping)
      when is_atom(module) and is_map(field_mapping) do
    # keys = module.string_keys()

    converter = fn
      {k, v}, acc when is_map_key(acc, k) ->
        convert_field_val(field_mapping[k], v)
        |> case do
          {:ok, val} ->
            acc = %{acc | k => val}
            {:cont, acc}

          :error ->
            {:halt, :error}

          {:error, _reason} ->
            {:halt, :error}
        end

      _kv, acc ->
        {:cont, acc}
    end

    msg_obj.values
    |> Enum.reduce_while(
      module.new(),
      converter
    )
  end

  defp convert_field_val(nil, value), do: {:ok, value}
  defp convert_field_val(conv_fn, value), do: conv_fn.(value)

  @doc """
  Utility function, converts string encoded hex to int. Or returns the values if it is already int.
  """
  def to_number(value) when is_binary(value) do
    case Integer.parse(value, 16) do
      {num, ""} ->
        {:ok, num}

      {_num, _rest} ->
        :error

      error ->
        error
    end
  end

  def to_number(value) when is_integer(value), do: {:ok, value}


  @doc """
  helper for converting content of the `a` event field,
  converts a list of `Jason.OrderedObject`s, assuming that they are _seals_, to a list of maps
  """
  def anchor_handler(anchors) when is_list(anchors) do
    Enum.reduce_while(
      anchors,
      [],
      fn anchor, acc ->
        case to_storage_format(anchor, Seal, %{"s" => &to_number/1}) do
          :error ->
            {:halt, :error}

          seal ->
            {:cont, {:ok, [seal | acc]}}
        end
      end
    )
  end
  @doc """
  compares `KEL` data structures using `BADA` (Best Available Data Acceptance) policy
  """
  def bada_check?(new_data, old_data)

  alias Watcher.KeyState.Endpoint

  def bada_check?(%Endpoint{} = endpoint, %Endpoint{} = o_endpoint) do
    cond do
      endpoint.said == o_endpoint.said ->
        false

      endpoint.dt > o_endpoint.dt ->
        true

      # different said, but new dt is older or the same
      true ->
        false
    end
  end

  def ordered_object_to_map(%OO{} = obj) do
    for kv <- obj.values, reduce: %{} do
      res ->
        case kv do
          {k, %OO{} = eo} ->
            eom = ordered_object_to_map(eo)
            Map.put(res, k, eom)

          {k, v} when is_list(v) ->
            nv = conv_list_values(v)
            Map.put(res, k, nv)

          {k, v} ->
            Map.put(res, k, v)
        end
    end
  end

  defp conv_list_values(list) do
    for v <- list, into: [] do
      case v do
        %OO{} = obj ->
          ordered_object_to_map(obj)

        data ->
          data
      end
    end
  end
end
