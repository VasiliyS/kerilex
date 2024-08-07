defmodule ServerSideEvent do
  @moduledoc """
  ServerSideEvents.Event Struct
  """
  @type t :: %__MODULE__{
          type: nil | String.t(),
          data: [String.t()],
          id: nil | String.t(),
          retry: nil | integer(),
          comments: [String.t()]
        }

  defstruct type: nil,
            data: [],
            id: nil,
            retry: nil,
            comments: []
end

defmodule ServerSideEvents do
  @moduledoc """
  Efficient ServerSideEvents.Parser
  adopted from https://github.com/CrowdHailer/server_sent_event.ex
  """

  @new_line ["\r\n", "\r", "\n"]
  @field_name_terminator [": ", ":"]

  @doc """
  Parse all events from text stream.

  ## Examples
  *In these examples this module has been aliased to `ServerSideEvents.*.

      iex> ServerSideEvents.parse_all("data: First message\\n\\ndata: Second\\ndata: message\\n\\nrest")
      {:ok,
        {
          [
            %ServerSideEvent{data: ["First message"]},
            %ServerSideEvent{data: ["Second", "message"]}
          ],
          "rest"
        }
      }

      iex> ServerSideEvents.parse_all("data: This is the first message\\n\\n")
      {:ok, {[%ServerSideEvent{data: ["This is the first message"]}], ""}}

      iex> ServerSideEvents.parse_all("data: This is the first message\\n\\nrest")
      {:ok, {[%ServerSideEvent{data: ["This is the first message"]}], "rest"}}

      iex> ServerSideEvents.parse_all("data: This message is not complete")
      {:ok, {[], "data: This message is not complete"}}

      iex> ServerSideEvents.parse_all("This line is invalid\\nit doesn't contain a colon\\n")
      {:error, {:malformed_line, "This line is invalid"}}

      iex> ServerSideEvents.parse_all("data: This is the first message\\n\\nThis line is invalid\\n")
      {:error, {:malformed_line, "This line is invalid"}}

      iex> ServerSideEvents.parse_all("data: This is the first message\\n\\nThis line is yet to terminate")
      {:ok, {[%ServerSideEvent{data: ["This is the first message"]}], "This line is yet to terminate"}}

  """
  @spec parse_all(String.t()) ::
          {:ok, {[event :: ServerSideEvent.t()], rest :: String.t()}}
          | {:error, term}
  def parse_all(stream) do
    case do_parse_all(stream, []) do
      {:ok, {evts, rest}} ->
        {:ok, {Enum.reverse(evts), rest}}

      err ->
        err
    end
  end

  defp do_parse_all(stream, events) do
    case parse(stream) do
      {:ok, {nil, rest}} ->
        {:ok, {events, rest}}

      {:ok, {evt, rest}} ->
        do_parse_all(rest, [evt | events])

      err ->
        err
    end
  end

  @doc ~S"""
  Parse the next event from text stream, if present.

  ## Examples
  *In these examples this module has been aliased to `ServerSideEvents.*.

  iex> ServerSideEvents.parse("data: This is the first message\n\n")
  {:ok, {%ServerSideEvent{data: ["This is the first message"]}, ""}}

  iex> ServerSideEvents.parse("data:First whitespace character is optional\n\n")
  {:ok, {%ServerSideEvent{data: ["First whitespace character is optional"]}, ""}}

  iex> ServerSideEvents.parse("data: This message\ndata: has two lines.\n\n")
  {:ok, {%ServerSideEvent{data: ["This message", "has two lines."]}, ""}}

  iex> ServerSideEvents.parse("data: This is the first message\n\nrest")
  {:ok, {%ServerSideEvent{data: ["This is the first message"]}, "rest"}}

  iex> ServerSideEvents.parse("data: This message is not complete")
  {:ok, {nil, "data: This message is not complete"}}

  iex> ServerSideEvents.parse("This line is invalid\nit doesn't contain a colon\n")
  {:error, {:malformed_line, "This line is invalid"}}

  iex> ServerSideEvents.parse("event: custom\ndata: This message is type custom\n\n")
  {:ok, {%ServerSideEvent{type: "custom", data: ["This message is type custom"]}, ""}}

  iex> ServerSideEvents.parse("id: 100\ndata: This message has an id\n\n")
  {:ok, {%ServerSideEvent{id: "100", data: ["This message has an id"]}, ""}}

  iex> ServerSideEvents.parse("retry: 5000\ndata: This message retries after 5s.\n\n")
  {:ok, {%ServerSideEvent{retry: 5000, data: ["This message retries after 5s."]}, ""}}

  iex> ServerSideEvents.parse("retry: five thousand\ndata: retry value is not a valid integer\n\n")
  {:error, {:invalid_retry_value, "five thousand"}}

  iex> ServerSideEvents.parse(": This is a comment\n\n")
  {:ok, {%ServerSideEvent{comments: ["This is a comment"]}, ""}}

  iex> ServerSideEvents.parse("data: data can have more :'s in it'\n\n")
  {:ok, {%ServerSideEvent{data: ["data can have more :'s in it'"]}, ""}}

  iex> ServerSideEvents.parse("DATA: field names are case-sensitive\n\n")
  {:error, {:invalid_field_name, "DATA"}}

  iex> ServerSideEvents.parse("unknown: what is this field?\n\n")
  {:error, {:invalid_field_name, "unknown"}}

  # It is possible for an event stream using `CRLF` to be split mid line delimiter.
  # In this case the parser needs to clear the leading newline character.
  iex> ServerSideEvents.parse("data: This is the first message\r\n\r")
  {:ok, {%ServerSideEvent{data: ["This is the first message"]}, ""}}

  iex> ServerSideEvents.parse("\ndata: This is the second message\r\n\r\n")
  {:ok, {%ServerSideEvent{data: ["This is the second message"]}, ""}}
  """
  # parse_block block has comments event does not
  @spec parse(String.t()) ::
          {:ok, {event :: ServerSideEvent.t() | nil, rest :: String.t()}}
          | {:error, term}
  def parse(<<lead_charachter, rest::binary>>) when lead_charachter in [?\r, ?\n] do
    parse(rest)
  end

  def parse(stream) do
    do_parse(stream, %ServerSideEvent{}, stream)
  end

  defp do_parse(stream, event, original) do
    case pop_line(stream) do
      nil ->
        {:ok, {nil, original}}

      {"", rest} ->
        {:ok, {event, rest}}

      {line, rest} ->
        with {:ok, event} <- process_line(line, event),
             do: do_parse(rest, event, original)
    end
  end

  defp pop_line(stream) do
    case :binary.split(stream, @new_line) do
      [^stream] ->
        nil

      [line, rest] ->
        {line, rest}
    end
  end

  defp process_line(line, event) do
    case :binary.split(line, @field_name_terminator) do
      ["", value] ->
        process_field("comment", value, event)

      [field, value] ->
        process_field(field, value, event)

      _ ->
        {:error, {:malformed_line, line}}
    end
  end

  defp process_field("event", type, event) do
    {:ok, Map.put(event, :type, type)}
  end

  defp process_field("data", line, event = %{data: lines}) do
    {:ok, %{event | data: lines ++ [line]}}
  end

  defp process_field("id", id, event) do
    {:ok, Map.put(event, :id, id)}
  end

  defp process_field("retry", timeout, event) do
    case Integer.parse(timeout) do
      {timeout, ""} ->
        {:ok, Map.put(event, :retry, timeout)}

      _err ->
        {:error, {:invalid_retry_value, timeout}}
    end
  end

  defp process_field("comment", comment, event = %{comments: comments}) do
    {:ok, %{event | comments: comments ++ [comment]}}
  end

  defp process_field(other_field_name, _value, _event) do
    {:error, {:invalid_field_name, other_field_name}}
  end
end
