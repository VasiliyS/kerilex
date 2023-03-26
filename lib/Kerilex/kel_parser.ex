defmodule Kerilex.KEL do
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

  def check_msg_integrity(%{serd_msg: serd_msg} = keri_msg) do
    with {:ok, parsed_msg} <-
           serd_msg
           |> Jason.decode(objects: :ordered_objects),
         :ok <- parsed_msg |> validate_said(),
         :ok <- parsed_msg |> check_sigs(keri_msg) do
      {:ok, Map.put(keri_msg, :parsed_msg, parsed_msg)}
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
         {:ok, said} <- type |> get_said(pmsg),
         :ok <- said |> comp_said(dig) do
      :ok
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

  def get_said(type, pmsg) do
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
      {:error, reason} ->
        {:error, reason}

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
         {:ok, hash_b64} <- hash |> Basic.binary_to_blake3_dig() do
      {:ok, hash_b64}
    else
      error ->
        error
    end
  end

  def check_sigs(parsed_msg, %{} = keri_msg) do
    if keri_msg |> Map.has_key?(Att.nt_rcpt_couples()) do
      check_witness_rcpts(keri_msg)
    else
      parsed_msg |> check_idx_sigs(keri_msg)
    end
  end

  defp check_witness_rcpts(%{serd_msg: serd_msg} = keri_msg) do
    keri_msg
    |> Map.fetch!(Att.nt_rcpt_couples())
    |> Att.NonTransReceiptCouples.check(serd_msg)
  end

  defp check_idx_sigs(parsed_msg, %{serd_msg: serd_msg} = keri_msg) do
    with {:ok, wit_sigs} <-
           keri_msg
           |> Map.fetch(Att.idx_wit_sigs())
           |> wrap_error("missing witness signatures"),
         :ok <- parsed_msg |> check_backer_sigs(serd_msg, wit_sigs),
         {:ok, ctrl_sigs} <-
           keri_msg
           |> Map.fetch(Att.idx_ctrl_sigs())
           |> wrap_error("missing controller signatures"),
         :ok <- parsed_msg |> check_ctrl_sigs(serd_msg, ctrl_sigs) do
      :ok
    else
      error ->
        error
    end

    :ok
  end

  defp check_backer_sigs(parsed_msg, serd_msg, wit_sigs) do
    with {:ok, backers_lst} <- parsed_msg |> get_list_of("b"),
         :ok <- backers_lst |> validate_idx_sigs(wit_sigs, serd_msg) do
      :ok
    else
      {:error, reason} ->
        {:error, "witness signature check failed:" <> reason}
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
    if length(key_lst) != length(idx_sigs) do
      {:error, "number of keys and sigs don't match"}
    else
      key_lst
      # [{key, ind},...]
      |> Stream.with_index()
      # [{{key, ind}, sig}, ...]
      |> Stream.zip(idx_sigs)
      |> Enum.reduce_while(
        nil,
        fn {key_idx, sig}, _acc ->
          validate_idx_sig(key_idx, sig, data)
          |> case do
            :ok ->
              {:cont, :ok}

            error ->
              {:halt, error}
          end
        end
      )
    end
  end

  alias Kerilex.Attachment.Signature, as: Sig

  defp validate_idx_sig({key_qb64, key_idn}, %{sig: sig, ind: sidn}, data) do
    if key_idn != sidn do
      {:error, "key #{key_qb64} order doesn't match that of sig, key:#{key_idn} sig:#{sidn}"}
    else
      Sig.check_with_qb64key(sig, data, key_qb64)
    end
  end

  defp check_ctrl_sigs(_parsed_msg, _serd_msg, _ctrl_sigs) do
    :ok
  end
end
