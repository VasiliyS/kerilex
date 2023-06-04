defmodule Kerilex.KELParser do
  @moduledoc """
    parser functions for a KERI KEL data
  """

  alias Kerilex.Attachment, as: Att
  alias Jason.OrderedObject, as: OO

  def parse(kel) do
    extract_messages(kel, [])
  end

  defp extract_messages(<<>>, msgs) do
    msgs |> Enum.reverse()
  end

  defp extract_messages(kel, msgs) do
    with {:keri_msg, size} <- sniff_type(kel),
         {:ok, msg, rest_kel} <- extract_message(kel, size),
         {:ok, msg, rest_kel} <- extract_and_parse_att(rest_kel, msg) do
      extract_messages(rest_kel, [msg | msgs])
    end
  end

  defp sniff_type(<<(~S|{"v":"KERI10JSON|), hex_size::binary-size(6), _::bitstring>>) do
    Integer.parse(hex_size, 16)
    |> case do
      :error ->
        {:error, "KERI version, bad size format: #{hex_size}"}

      {size, _} ->
        {:keri_msg, size}
    end
  end

  defp sniff_type(<<"-0", code, _::bitstring>>), do: {:keri_att, code}
  defp sniff_type(<<"-", code, _::bitstring>>), do: {:keri_att, code}
  # TODO(VS): define unknown type handler

  defp extract_message(kel, size) do
    try do
      <<msg::binary-size(size), kel_rest::bitstring>> = kel
      {:ok, %{serd_msg: msg}, kel_rest}
    rescue
      MatchError -> {:error, "wrong msg size, want: #{size}, have: #{byte_size(kel)}"}
    end
  end

  def extract_and_parse_att(kel, msg) do
    kel
    |> Att.parse()
    |> wrap_error("parser error")
    |> case do
      {:ok, pa, kel_rest} ->
        {:ok, Map.merge(msg, pa), kel_rest}

      {:error, reason} ->
        as =
          kel
          |> byte_size()
          |> min(10)

        {:error, "couldn't parse the attachment: '#{binary_part(kel, 0, as)}...', #{reason}"}
    end
  end

  @doc """
  Parses serialized (json) message from the parser's output (`keri_msg`), validates it's `said`.

  Returns `{error: reason}` or `{:ok, parsed_msg}`. `parsed_msg` is `%Jason.OrderedObject`
  """
  def check_msg_integrity(%{serd_msg: serd_msg} = keri_msg) do
    with {:ok, parsed_msg} <-
           serd_msg
           |> Jason.decode(objects: :ordered_objects),
         :ok <- parsed_msg |> validate_said() do
      {:ok, parsed_msg}
    else
      {:error, reason} ->
        {:error, "msg integrity check failed: #{reason} "}
    end
  end

  def validate_said(%Jason.OrderedObject{} = pmsg) do
    with {:ok, type} <-
           OO.fetch(pmsg, "t")
           |> wrap_error("msg has no type"),
         {:ok, dig} <-
           OO.fetch(pmsg, "d")
           |> wrap_error("msg has no digest"),
         {:ok, said} <- type |> get_said(pmsg) do
      said |> comp_said(dig)
    else
      {:error, reason} ->
        {:error, "said validity check failed: #{reason}"}
    end
  end

  defp wrap_error(term, msg)

  defp wrap_error(:error, msg) do
    {:error, msg}
  end

  defp wrap_error(term, _), do: term

  defp comp_said(said, dig) do
    if said == dig do
      :ok
    else
      {:error, "digest mismatch, wanted: #{dig}, got: #{said}"}
    end
  end

  @saidify_labels %{"icp" => ["d", "i"], "dip" => ["d", "i"]}

  @doc """
      takes a type (e.g. 'icp', 'dip', etc)
      and calculates said of the KERI message
  """
  def get_said(type, %OO{} = pmsg) do
    @saidify_labels
    |> Map.fetch(type)
    |> case do
      {:ok, ll} ->
        ll

      _ ->
        ["d"]
    end
    |> saidify(pmsg)
  end

  @said_placeholder String.duplicate("#", 44)

  defp saidify(ll, pmsg) do
    ll
    |> put_placeholders(pmsg)
    |> case do
      {:error, _reason} = err ->
        err

      msg_with_placeholders ->
        calc_said(msg_with_placeholders)
    end
  end

  defp put_placeholders(ll, pmsg) do
    put_placeholder = fn
      nil -> :pop
      val -> {val, @said_placeholder}
    end

    ll
    |> Enum.reduce_while(
      pmsg,
      fn label, pmsg ->
        pmsg
        |> OO.get_and_update(label, put_placeholder)
        |> case do
          {nil, _} ->
            {:halt, {:error, "msg has no '#{label}'"}}

          {_, pmsg} ->
            {:cont, pmsg}
        end
      end
    )
  end

  alias Kerilex.Derivation.Basic

  defp calc_said(pmsg) do
    with {:ok, emsg} <- pmsg |> Jason.encode(),
         hash = emsg |> Blake3.hash(),
         {:ok, hash_b64} <- hash |> Basic.to_qb64_blake3_dig() do
      {:ok, hash_b64}
    else
      error ->
        error
    end
  end

  @doc """
   Verifies signatures on parsed messages that have required keys, backers, etc
   this includes `rpy` and establishment messages (e.g. `icp`, `dip`, `rot` and `drt`)


   Returns `:ok` or `{:error, reason}`
  """
  def check_sigs_on_stateful_msg(msg_obj, %{} = parsed_msg) do
    if parsed_msg |> Map.has_key?(Att.nt_rcpt_couples()) do
      check_witness_rcpts(parsed_msg)
    else
      msg_obj |> check_all_idx_sigs(parsed_msg)
    end
  end

  defp check_witness_rcpts(%{serd_msg: serd_msg} = keri_msg) do
    keri_msg
    |> Map.fetch!(Att.nt_rcpt_couples())
    |> Att.NonTransReceiptCouples.check(serd_msg)
  end

  defp check_all_idx_sigs(parsed_msg, %{serd_msg: serd_msg} = keri_msg) do
    with {:ok, wit_sigs} <-
           keri_msg
           |> Map.fetch(Att.idx_wit_sigs())
           |> wrap_error("missing witness signatures"),
         {:ok, b_indices} <- parsed_msg |> check_backer_sigs(serd_msg, wit_sigs),
         :ok <- parsed_msg |> check_backer_threshold(b_indices),
         {:ok, ctrl_sigs} <-
           keri_msg
           |> Map.fetch(Att.idx_ctrl_sigs())
           |> wrap_error("missing controller signatures"),
         {:ok, c_indices} <- parsed_msg |> check_ctrl_sigs(serd_msg, ctrl_sigs) do
      parsed_msg |> check_ctrl_threshold(c_indices)
    end
  end

  defp check_backer_sigs(parsed_msg, serd_msg, wit_sigs) do
    check_idx_sigs(parsed_msg, serd_msg, wit_sigs, "b")
    |> case do
      {:error, reason} ->
        {:error, "witness signature check failed:" <> reason}

      res ->
        res
    end
  end

  defp check_idx_sigs(parsed_msg, serd_msg, idx_sigs, key) do
    with {:ok, verkey_lst} <- parsed_msg |> get_list_of(key) do
      verkey_lst |> validate_idx_sigs(idx_sigs, serd_msg)
    end
  end

  defp get_list_of(parsed_msg, key) do
    parsed_msg
    |> OO.fetch(key)
    |> case do
      {:ok, lst} = res when is_list(lst) ->
        res

      {:ok, val} ->
        {:error, "expected a list under label '#{key}', got: #{inspect(val)}"}

      :error ->
        {:error, "msg missing data under key: '#{key}'"}
    end
  end

  defp validate_idx_sigs([], _idx_sigs, _data), do: {:error, "msg has an empty key list"}

  defp validate_idx_sigs(key_lst, idx_sigs, data) do
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

  alias Kerilex.Attachment.Signature, as: Sig

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

  defp check_backer_threshold(parsed_msg, indices) do
    with {:ok, bt} <-
           parsed_msg
           |> OO.fetch("bt")
           |> wrap_error("backer threshold entry ('bt') is missing"),
         {t, ""} <-
           bt
           |> Integer.parse(16)
           |> wrap_error("can't parse 'bt' as hex int, got: #{inspect(bt)}") do
      if(length(indices) < t) do
        {:error,
         "number of backers sigs (#{length(indices)}) is lower than the required threshold: #{t}"}
      else
        :ok
      end
    end
  end

  alias Kerilex.Crypto.KeyTally

  defp check_ctrl_threshold(parsed_msg, indices) do
    with {:ok, kt} <-
           parsed_msg
           |> OO.fetch("kt")
           |> wrap_error("key threshold entry ('kt') is missing"),
         {:ok, t} <- KeyTally.new(kt) do
      if t |> KeyTally.satisfy?(indices) do
        :ok
      else
        {:error, "key threshold: #{kt} wasn't satisfied by sig indices: #{inspect(indices)}"}
      end
    end
  end
end
