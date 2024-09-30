defmodule Kerilex.KELParser.Integrity do
  @moduledoc """
  helpers to validate integrity of parsed KEL elements
  """
  alias Kerilex.{Crypto, KELParser, Attachment}
  alias Kerilex.Crypto.KeyTally
  alias Kerilex.Attachment.Signature, as: Sig
  alias Jason.OrderedObject, as: OO

  import Kerilex.Helpers

  @said_placeholder String.duplicate("#", 44)
  @keri_10_json_head_to_d_length byte_size(~S|{"v":"KERI10JSON00049d_","t":"icp",|)
  @keri_10_json_d_start ~S|"d":"|
  @keri_10_json_i_start ~S|"i":"|
  @keri_10_json_quote_coma ~S|",|

  @doc """
    takes a parsed KEL element and validates that its `d` field (`said`) is correct
  """
  @spec check_msg_integrity(KELParser.parsed_kel_element()) ::
          :ok | {:error, String.t()}
  def check_msg_integrity(%{serd_msg: msg_json}) do
    {msg_d_val, saidified_msg_data} =
      case msg_json do
        # KERI event template
        <<head_to_d::binary-size(@keri_10_json_head_to_d_length), @keri_10_json_d_start,
          d_val::binary-size(44), @keri_10_json_quote_coma, @keri_10_json_i_start,
          i_val::binary-size(44), rest::bitstring>> ->
          res =
            if i_val == d_val do
              [
                head_to_d,
                @keri_10_json_d_start,
                @said_placeholder,
                @keri_10_json_quote_coma,
                @keri_10_json_i_start,
                @said_placeholder,
                rest
              ]
            else
              [
                head_to_d,
                @keri_10_json_d_start,
                @said_placeholder,
                @keri_10_json_quote_coma,
                @keri_10_json_i_start,
                i_val,
                rest
              ]
            end

          {d_val, res}

        # KERI message, such as 'rpy' template, has no 'i' field.
        <<head_to_d::binary-size(@keri_10_json_head_to_d_length), @keri_10_json_d_start,
          d_val::binary-size(44), rest::bitstring>> ->
          {d_val, [head_to_d, @keri_10_json_d_start, @said_placeholder, rest]}

        _ ->
          raise "badly formatted KERI 1.0 event or 'rpy' message : '#{msg_json}'"
      end

    verify_said(IO.iodata_to_binary(saidified_msg_data), msg_d_val)
  rescue
    e ->
      {:error, Exception.message(e)}
  end

  defp verify_said(saidified_msg, orig_d_val) do
    calculated_d_val = Crypto.hash_and_encode!(saidified_msg)

    if calculated_d_val != orig_d_val do
      {:error, "said validation failed, expected d: '#{orig_d_val}' got: '#{calculated_d_val}'"}
    else
      :ok
    end
  end


  @doc """
   Verifies signatures on parsed messages that have required keys, backers, etc
   this includes `rpy` and establishment messages (e.g. `icp`, `dip`)


   Returns `:ok` or `{:error, reason}`
  """
  def check_sigs_on_stateful_msg(msg_obj, %{} = parsed_msg) do
    if parsed_msg |> Map.has_key?(Attachment.nt_rcpt_couples()) do
      check_witness_rcpts(parsed_msg)
    else
      msg_obj |> check_all_idx_sigs(parsed_msg)
    end
  end

  @doc """
   Verifies signatures or `rot` and `drt` that depend on state calculations

   Returns `:ok` or `{:error, reason}`
  """
  def check_sigs_on_rot_msg(msg_obj, backers, %{serd_msg: serd_msg} = keri_msg) do
    with {:ok, wit_sigs} <-
           keri_msg
           |> Map.fetch(Attachment.idx_wit_sigs())
           |> wrap_error("missing witness signatures"),
         {:ok, b_indices} <- check_backer_sigs(serd_msg, wit_sigs, backers),
         :ok <- msg_obj |> check_backer_threshold(b_indices),
         {:ok, ctrl_sigs} <-
           keri_msg
           |> Map.fetch(Attachment.idx_ctrl_sigs())
           |> wrap_error("missing controller signatures"),
         {:ok, _c_indices} <- msg_obj |> check_ctrl_sigs(serd_msg, ctrl_sigs) do
      :ok
    end
  end


  # REFACTOR(VS): this is an ugly hack !!
  # this one is used for `rot` and `drt` messages
  def check_backer_sigs(serd_msg, wit_sigs, backers) when is_bitstring(serd_msg) do
    backers
    |> validate_idx_sigs(wit_sigs, serd_msg)
    |> case do
      {:error, reason} ->
        {:error, "witness signature check failed: " <> reason}

      res ->
        res
    end
  end

  # this one is used for `icp` and `dip` messages
  def check_backer_sigs(parsed_msg, serd_msg, wit_sigs) when is_bitstring(serd_msg) do
    check_idx_sigs(parsed_msg, serd_msg, wit_sigs, "b")
    |> case do
      {:error, reason} ->
        {:error, "witness signature check failed: " <> reason}

      res ->
        res
    end
  end

  defp check_witness_rcpts(%{serd_msg: serd_msg} = keri_msg) do
    keri_msg
    |> Map.fetch!(Attachment.nt_rcpt_couples())
    |> Attachment.NonTransReceiptCouples.check(serd_msg)
  end

  defp check_all_idx_sigs(parsed_msg, %{serd_msg: serd_msg} = keri_msg) do
    with {:ok, wit_sigs} <-
           keri_msg
           |> Map.fetch(Attachment.idx_wit_sigs())
           |> wrap_error("missing witness signatures"),
         {:ok, b_indices} <- parsed_msg |> check_backer_sigs(serd_msg, wit_sigs),
         :ok <- parsed_msg |> check_backer_threshold(b_indices),
         {:ok, ctrl_sigs} <-
           keri_msg
           |> Map.fetch(Attachment.idx_ctrl_sigs())
           |> wrap_error("missing controller signatures"),
         {:ok, c_indices} <- parsed_msg |> check_ctrl_sigs(serd_msg, ctrl_sigs) do
      parsed_msg |> check_ctrl_threshold(c_indices)
    end
  end

  defp check_idx_sigs(parsed_msg, serd_msg, idx_sigs, key) do
    with {:ok, verkey_lst} <- parsed_msg |> get_list_of(key) do
      verkey_lst |> validate_idx_sigs(idx_sigs, serd_msg)
    end
  end

  defp get_list_of(parsed_msg, key) do
    parsed_msg[key]
    # |> OO.fetch(key)
    |> case do
      lst when is_list(lst) ->
        {:ok, lst}

      val when val != nil ->
        {:error, "expected a list under label '#{key}', got: #{inspect(val)}"}

      nil ->
        {:error, "msg missing data under key: '#{key}'"}
    end
  end

  def validate_idx_sigs([], _idx_sigs, _data), do: {:error, "msg has an empty key list"}

  def validate_idx_sigs(key_lst, idx_sigs, data) do
    nok = length(key_lst)

    idx_sigs
    |> Enum.reduce_while(
      _acc = {:ok, []},
      fn sig, {:ok, indices} ->
        validate_idx_sig(nok, key_lst, sig, data)
        |> case do
          :ok ->
            %{ind: sind} = sig
            {:cont, {:ok, [sind | indices]}}

          error ->
            {:halt, error}
        end
      end
    )
  end

  defp validate_idx_sig(no_keys, key_lst, %{sig: sig, ind: sind}, data) do
    if sind > no_keys do
      {:error, "sig ind error: got: #{sind}, total keys: #{no_keys}"}
    else
      key_qb64 = key_lst |> Enum.at(sind)
      Sig.check_with_qb64key(sig, data, key_qb64)
    end
  end

  defp check_ctrl_sigs(parsed_msg, serd_msg, ctrl_sigs) do
    check_idx_sigs(parsed_msg, serd_msg, ctrl_sigs, "k")
    |> case do
      {:error, reason} ->
        {:error, "controller signature check failed:" <> reason}

      res ->
        res
    end
  end

  ################## threshold validation #######################

  defp check_backer_threshold(event, indices) when is_struct(event, OO) do
    with {:ok, bt} <-
           event
           #  |> IO.inspect(label: "event in check_backer_threshold")
           |> OO.fetch("bt")
           |> wrap_error("backer threshold entry ('bt') is missing"),
         {t, ""} <-
           bt
           |> Integer.parse(16)
           |> wrap_error("can't parse 'bt' as hex int, got: #{inspect(bt)}") do
      if length(indices) < t do
        {:error,
         "number of backers sigs (#{length(indices)}) is lower than the required threshold: #{t}"}
      else
        :ok
      end
    end
  end

  defp check_backer_threshold(event, indices) do
    if length(indices) < event["bt"] do
      {:error,
       "number of backers sigs (#{length(indices)}) is lower than the required threshold: #{event["bt"]}"}
    else
      :ok
    end
  end

  defp check_ctrl_threshold(parsed_msg, indices) do
    with {:ok, kt} <-
           parsed_msg
           |> OO.fetch("kt")
           |> wrap_error("key threshold entry ('kt') is missing"),
         {:ok, t} <- KeyTally.new(kt) do
      if t |> KeyTally.satisfy?(indices) do
        {:ok, t}
      else
        {:error, "key threshold: #{kt} wasn't satisfied by sig indices: #{inspect(indices)}"}
      end
    end
  end
end
