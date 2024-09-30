defmodule Kerilex.KELParser do
  @moduledoc """
    parser functions for a KERI KEL data
  """

  alias Kerilex.Attachment

  alias Kerilex.Attachment.{
    IndexedWitnessSig,
    IndexedControllerSig,
    SealSourceCouple,
    ReplayCouple,
    NonTransReceiptCouple
  }

  import Kerilex.Helpers

  @event_or_rpy_re ~r/\G"t":"(?<t>.{3})","d":"(?<d>.{44})"(,"i":"(?<i>.{44})","s":"(?<s>.*?)")?/
  @keri_10_json_start ~S|{"v":"KERI10JSON|
  @keri_10_json_header @keri_10_json_start <> ~S|xxxxxx_",|
  # KERI10JSON<hex size>, the length of the <hex size> part, bytes
  @keri_10_json_size_length 6
  @re_start_offset byte_size(@keri_10_json_header)

  @type parsed_kel_event :: %{
          :serd_msg => Kerilex.json_binary(),
          :idx_wit_sigs => [IndexedWitnessSig.t()] | nil,
          :idx_ctrl_sigs => [IndexedControllerSig.t()] | nil,
          :fs_repl_couples => [ReplayCouple.t()] | nil,
          optional(:seal_src_couples) => [SealSourceCouple.t()]
        }

  @type parsed_rpy_msg :: %{
          serd_msg: Kerilex.json_binary(),
          nt_rcpt_couples: [NonTransReceiptCouple.t()] | nil
        }

  @type parsed_kel_element :: parsed_kel_event() | parsed_rpy_msg()
  @type filter_fn :: (Kerilex.kel_ilk(), Kerilex.said(), Kerilex.pre(), Kerilex.hex_sn() ->
                        :skip | :cont | {:halt, {:error, String.t}})

  @type option() :: {:filter_fn, filter_fn()}
  @type options() :: [option()]

  @spec new_parsed_key_event(Kerilex.json_binary()) :: parsed_kel_event()
  def new_parsed_key_event(serd_msg),
    do: %{serd_msg: serd_msg, idx_wit_sigs: nil, idx_ctrl_sigs: nil, fs_repl_couples: nil}

  @spec new_parsed_rpy_msg(Kerilex.json_binary()) :: parsed_rpy_msg()
  def new_parsed_rpy_msg(serd_msg), do: %{serd_msg: serd_msg, nt_rcpt_couples: nil}

  @doc """
  parses KERI KERL, such as a response from an `OOBI` endpoint

  takes optional `:filter_fn` option, a function that takes `type`, `said`, AID `prefix`, hex encoded `sn` and returns either `:cont` or `:skip`

  """
  @spec parse(bitstring(), options()) :: list(parsed_kel_element()) | {:error, String.t()}
  def parse(kel, opts \\ []) do
    filter_fn = Keyword.get(opts, :filter_fn)

    if filter_fn do
      extract_messages(kel, [], filter_fn)
    else
      extract_messages(kel, [])
    end
  end

  defp extract_messages(<<>>, parsed_elements) do
    parsed_elements |> Enum.reverse()
  end

  defp extract_messages(kel, parsed_elements) do
    with {:keri_msg, size} <- sniff_type(kel),
         {:ok, msg, rest_kel} <- extract_message(kel, size),
         {:ok, parsed_kel_element} <- init_parsed_kel_element(msg),
         {:ok, parsed_kel_element, rest_kel} <-
           extract_and_parse_att(rest_kel, parsed_kel_element) do
      extract_messages(rest_kel, [parsed_kel_element | parsed_elements])
    else
      {:keri_att, code} ->
        {:error, "expected a KERI JSON message, got CESR code: '#{code}'"}

      err ->
        err
    end
  end

  defp extract_messages(<<>>, parsed_elements, _filter_fn) do
    parsed_elements |> Enum.reverse()
  end

  defp extract_messages(kel, parsed_elements, filter_fn) do
    with {:keri_msg, size} <- sniff_type(kel),
         {:ok, msg, rest_kel} <- extract_message(kel, size),
         {:ok, parsed_kel_element} <- init_parsed_kel_element(msg),
         {:ok, t, d, i, s} <- get_msg_data(parsed_kel_element) do
      continue_extract_messages(
        filter_fn.(t, d, i, s),
        parsed_kel_element,
        parsed_elements,
        rest_kel,
        filter_fn
      )
    else
      {:keri_att, code} ->
        {:error, "expected a KERI JSON message, got CESR code: '#{code}'"}

      err ->
        err
    end
  end

  @compile {:inline, get_msg_data: 1}
  defp get_msg_data(%{serd_msg: json}) do
    case Regex.run(@event_or_rpy_re, json, offset: @re_start_offset, capture: [:t, :d, :i, :s]) do
      [t, d, i, s] ->
        {:ok, t, d, i, s}

      nil ->
        {:error, "bad KERI event or message format"}
    end
  end

  @compile {:inline, get_msg_type: 1}
  defp get_msg_type(json) do
    case json do
      <<_head::binary-size(@re_start_offset), ~S|"t":"|, type::binary-size(3), _::bitstring>> ->
        {:ok, type}

      _ ->
        {:error, "bad KERI event or msg format"}
    end
  end

  defp continue_extract_messages(:cont, msg, msgs, rest_kel, filter_fn) do
    case extract_and_parse_att(rest_kel, msg) do
      {:ok, msg, rest_kel} ->
        extract_messages(rest_kel, [msg | msgs], filter_fn)

      err ->
        err
    end
  end

  defp continue_extract_messages(:skip, _msg, msgs, rest_kel, filter_fn) do
    case skip_att(rest_kel) do
      {:ok, rest_kel} ->
        extract_messages(rest_kel, msgs, filter_fn)

      err ->
        err
    end
  end

  defp continue_extract_messages({:halt, err}, _msg, _msgs, _rest_kel, _filter_fn) do
    err
  end


  defp skip_att(kel) do
    kel
    |> Attachment.extract()
    |> wrap_error("parser error")
    |> case do
      {:ok, _att, kel_rest} ->
        {:ok, kel_rest}

      {:error, reason} ->
        as =
          kel
          |> byte_size()
          |> min(10)

        {:error, "couldn't parse the attachment: '#{binary_part(kel, 0, as)}...', #{reason}"}
    end
  end

  defp sniff_type(
         <<@keri_10_json_start, hex_size::binary-size(@keri_10_json_size_length), _::bitstring>>
       ) do
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

  defp sniff_type(<<head::binary-size(10), _::bitstring>>) do
    {:error, "encountered unknown encoding: '#{head}...'"}
  end

  @compile {:inline, extract_message: 2}
  defp extract_message(kel, size) do
    case kel do
      <<msg::binary-size(size), kel_rest::bitstring>> ->
        {:ok, msg, kel_rest}

      _ ->
        {:error, "wrong msg size, want: #{size}, have: #{byte_size(kel)}"}
    end
  end

  @compile {:inline, init_parsed_kel_element: 1}
  defp init_parsed_kel_element(msg) do
    with {:ok, type} <- get_msg_type(msg) do
      case type do
        "rpy" -> {:ok, new_parsed_rpy_msg(msg)}
        _ -> {:ok, new_parsed_key_event(msg)}
      end
    end
  end

  defp extract_and_parse_att(kel, msg) do
    kel
    |> Attachment.parse()
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
  takes a parsed KEL element and returns decoded JSON where `s` field, if present, was decoded from hex.
  """
  @spec decode_json(parsed_kel_element()) ::
          {:error, String.t()} | {:ok, Jason.OrderedObject.t()}
  def decode_json(parsed_kel_element)

  def decode_json(%{serd_msg: json}) do
    msg_obj = Jason.decode!(json, objects: :ordered_objects)

    if msg_obj["s"] do
      case hex_to_int(msg_obj["s"], "event's `s` field is not properly encoded") do
        {:ok, sn} ->
          msg_obj = update_in(msg_obj["s"], fn _ -> sn end)
          {:ok, msg_obj}

        err ->
          err
      end
    else
      {:ok, msg_obj}
    end
  rescue
    e -> {:error, Exception.message(e)}
  end


  @doc """
    returns a list of the source seal couples
  """
  def get_source_seal_couples(%{} = parsed_msg) do
    Map.fetch(parsed_msg, Attachment.seal_src_couples())
    |> case do
      {:ok, _} = res -> res
      :error -> {:error, "no source seal couples found"}
    end
  end
end
