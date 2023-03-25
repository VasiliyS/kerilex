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

  defp check_sigs(parsed_msg, %{} = keri_msg) do
    if keri_msg |> Map.has_key?(Att.nt_rcpt_couples()) do
      check_witness_rcpts(keri_msg)
    else
      parsed_msg |> check_idx_sigs(keri_msg)
    end
  end

  defp check_witness_rcpts(keri_msg) do
    serd_msg = keri_msg |> Map.fetch!(:serd_msg)

    keri_msg
    |> Map.fetch!(Att.nt_rcpt_couples())
    |> Att.NonTransReceiptCouples.check(serd_msg)
  end

  defp check_idx_sigs(_parsed_msg, _keri_msg) do
    :ok
  end
end
