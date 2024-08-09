defmodule Watcher.KeyState.IxnEvent do
  @moduledoc """
  defines interaction (`ixn`) event map for storing in the Key State Store
  """

  import Kerilex.Constants
  import Comment

  alias Kerilex.KELParser
  alias Jason.OrderedObject, as: OO
  alias Kerilex.Attachment, as: Att
  alias Watcher.KeyStateEvent, as: KSE
  alias Watcher.KeyState

  comment("""

        {
        "v": "KERI10JSON00013a_",
        "t": "ixn",
        "d": "ED9AwQj-DC__XqYS6TRC84_obUHpPwLTPUK35lxnBbHH",
        "i": "EINmHd5g7iV-UldkkkKyBIH052bIyxZNBn9pq-zNrYoS",
        "s": "1",
        "p": "EINmHd5g7iV-UldkkkKyBIH052bIyxZNBn9pq-zNrYoS",
        "a": [
          {
            "i": "ED88Jn6CnWpNbSYz6vp9DOSpJH2_Di5MSwWTf1l34JJm",
            "s": "0",
            "d": "ED88Jn6CnWpNbSYz6vp9DOSpJH2_Di5MSwWTf1l34JJm"
          }
        ]
      }

  """)

  @keys Kerilex.Event.ixn_labels()

  const(keys, @keys)

  def new do
    Map.from_keys(@keys, nil)
  end

  ################  conversion functionality, from parsed event (Jason.OrderedObject) to simplified map ready for processing and storage

  def from_ordered_object(%OO{} = msg_obj) do
    conversions = %{
      "s" => &KSE.to_number/1,
      "v" => &KSE.keri_version/1,
      "a" => &KSE.anchor_handler/1
    }

    KSE.to_storage_format(msg_obj, Watcher.KeyState.IxnEvent, conversions)
    |> case do
      :error ->
        {:error, "failed to convert ordered object to 'ixn' storage format"}

      ixn ->
        validate_event(ixn)
    end
  end

  @compile {:inline, validate_event: 1}
  defp validate_event(ixn) do
    cond do
      ixn["s"] == 0 ->
        {:error, "ixn event must have sn > 0, got: #{ixn["s"]}"}

      true ->
        {:ok, ixn}
    end
  end

  ######################## signature checking

  @doc """
   Verifies signatures on 'ixn' messages that depend on state calculations

   Returns `:ok` or `{:error, reason}`
  """
  def check_sigs(parsed_msg, %KeyState{} = key_state) do
    with {:ok, serd_msg} <- Map.fetch(parsed_msg, :serd_msg) |> wrap_error("serd_msg not found."),
         {:ok, wit_sigs} <-
           parsed_msg
           |> Map.fetch(Att.idx_wit_sigs())
           |> wrap_error("missing witness signatures"),
         {:ok, b_indices} <- KELParser.check_backer_sigs(serd_msg, wit_sigs, key_state.b),
         :ok <- KeyState.check_backer_threshold(key_state, b_indices),
         {:ok, ctrl_sigs} <-
           parsed_msg
           |> Map.fetch(Att.idx_ctrl_sigs())
           |> wrap_error("missing controller signatures"),
         {:ok, _c_indices} <- key_state |> KeyState.check_ctrl_sigs(serd_msg, ctrl_sigs) do
      :ok
    end
  end

  @compile {:inline, wrap_error: 2}
  defp wrap_error(term, msg)

  defp wrap_error(:error, msg) do
    {:error, msg}
  end

  defp wrap_error(term, _), do: term
end
