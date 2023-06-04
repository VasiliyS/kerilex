defmodule Watcher.KeyState.Endpoint do
  @moduledoc """
  Endpoint state
  """

  defstruct said: nil, URL: nil, dt: nil

  alias Jason.OrderedObject, as: OO

  def new(%OO{} = msg_obj) do
    case validate_data(msg_obj) do
      :ok ->
        {:ok, %__MODULE__{said: msg_obj["d"], URL: msg_obj["a"]["url"], dt: msg_obj["dt"]}}

      error ->
        error
    end
  end

  defp validate_data(msg_obj) do
    cond do

      msg_obj["dt"] == nil ->
        {:error, "missing 'dt' field"}

      match?({:error, _}, msg_obj["dt"] |> DateTime.from_iso8601()) ->
        {:error, "bad 'dt' field"}

      msg_obj["a"]["eid"] == nil ->
        {:error, "no 'eid' field in the attachment"}

      msg_obj["a"]["scheme"] == nil ->
        {:error, "no 'scheme' field in the attachment"}

      msg_obj["a"]["url"] == nil ->
        {:error, "no 'url' field in the attachment"}

      true ->
        :ok
    end
  end
end
