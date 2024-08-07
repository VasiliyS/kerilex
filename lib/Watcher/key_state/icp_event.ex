defmodule Watcher.KeyState.IcpEvent do
  @moduledoc """
  defines inception event map for storing in the Key State Store
  """
  import Kerilex.Constants

  alias Kerilex.Event

  @keys Event.icp_labels()

  const(string_keys, @keys)

  def new() do
    Map.from_keys(@keys, nil)
  end

  alias Jason.OrderedObject, as: OO
  alias Watcher.KeyStateEvent, as: KSE

  def from_ordered_object(%OO{} = msg_obj) do
    conversions = %{
      "s" => &KSE.to_number/1,
      "bt" => &KSE.to_number/1,
      "v" => &KSE.keri_version/1
    }

    KSE.to_storage_format(msg_obj, Watcher.KeyState.IcpEvent, conversions)
    |> case do
      :error ->
        {:error, "failed to convert ordered object to 'icp' storage format"}

      icp ->
        validate_event(icp)
    end
  end

  defp validate_event(icp) do
    cond do
      icp["s"] != 0 ->
        {:error, "icp event must have sn=0, got: #{icp["s"]}"}

      icp["d"] != icp["i"] ->
        {:error, "said and prefix mismatch, 'd'='#{icp["d"]}' and 'i'='#{icp["i"]}' , icp = '#{inspect(icp)}'"}


      true ->
        {:ok, icp}

    end
  end
end
