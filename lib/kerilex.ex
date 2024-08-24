defmodule Kerilex do
  @moduledoc """
  Documentation for `Kerilex`.
  """

  @doc """

  ## Examples

  """

  @typedoc """
   QB64 transferable or non-transferable prefix
   44 bytes
  """
  @type pre :: String.t

  @typedoc """
   QB64 self addressing identifier aka self-certifying identifier, a digest of event
   44 bytes
  """
  @type said :: String.t

  @typedoc """
  string representing a type of the event/message that can be found in a KEL
  "rpy" |  "icp" |  "rot" |  "ixn" | "dip" | "drt"
  """
  @type kel_ilk :: String.t

  @placeholder_char "#"

  def kel_sample do
    ~S|{"v":"KERI10JSON00010d_","t":"rpy","d":"ECyo9nSwhlzhvPAK46-rYi4qYUy_mbNwJOn5Ex-Ac3f8","dt":"2023-02-01T23:32:20.209420+00:00","r":"/loc/scheme","a":{"eid":"BDno6jGtzjMdf5jvlo1qvbM8qIy6bSYb5xTPm5-2exLE","scheme":"http","url":"http://witness1.stage.provenant.net:5631/"}}-VAi-CABBDno6jGtzjMdf5jvlo1qvbM8qIy6bSYb5xTPm5-2exLE0BBa7MYlvf2h6L32fjKN-Lv-5ox3OUSlkxfJB6-3Le6k4F7f8iixYsHZWv0TTn7-GLUlwW4C2z63U73wgQfcu8QK|
  end

  def process_cesr(<<(~S|{"v":"KERI10JSON|), hex_size::binary-size(6), _::binary>>) do
    res =
      case Integer.parse(hex_size, 16) do
        {json_size, _} ->
          IO.puts("detected JSON CESR fragment with #{json_size} length")
          json_size

        :error ->
          {:error, :bad_size_format}
      end

    res
  end

  def get_said(kel) when is_binary(kel) do
    kel
    |> Kerilex.process_cesr()
    |> then(&binary_part(kel, 0, &1))
    |> Jason.decode!(objects: :ordered_objects)
    |> Access.get_and_update("d", &{&1, Kerilex.said_placeholder(44)})
    |> then(fn {_nv, um} -> um end)
    |> Jason.encode!()
    |> Blake3.hash()
    |> then(&Kernel.<>(<<0>>, &1))
    |> Base.url_encode64()
    |> binary_part(1, 43)
    |> then(&Kernel.<>(<<"E">>, &1))
  end

  def get_said(%Jason.OrderedObject{} = event) do
    event
    |> Access.get_and_update("d", &{&1, Kerilex.said_placeholder(44)})
    |> then(fn {_nv, um} -> um end)
    |> Jason.encode!()
    |> Blake3.hash()
    |> then(&Kernel.<>(<<0>>, &1))
    |> Base.url_encode64()
    |> binary_part(1, 43)
    |> then(&Kernel.<>(<<"E">>, &1))
  end

  def get_said_icp(kel) do
    kel
    |> Kerilex.process_cesr()
    |> then(&binary_part(kel, 0, &1))
    |> Jason.decode!(objects: :ordered_objects)
    |> Access.get_and_update("d", &{&1, Kerilex.said_placeholder(44)})
    |> then(fn {_nv, um} -> um end)
    |> Access.get_and_update("i", &{&1, Kerilex.said_placeholder(44)})
    |> then(fn {_nv, um} -> um end)
    |> Jason.encode!()
    |> Blake3.hash()
    |> then(&Kernel.<>(<<0>>, &1))
    |> Base.url_encode64()
    |> binary_part(1, 43)
    |> then(&Kernel.<>(<<"E">>, &1))
  end

  def said_placeholder(length) do
    String.duplicate(@placeholder_char, length)
  end

  def dummy_string(char, length) do
    lst =
      Enum.reduce(
        1..length,
        ~c"",
        fn _, acc ->
          [char | acc]
        end
      )

    List.to_string(lst)
  end
end

defmodule Kerilex.Helpers do
  @moduledoc """
  Helper functions to deal with common tasks when processing KERI events/messages
  """

  @spec hex_to_int(binary() | integer(), String.t()) :: {:error, String.t()} | {:ok, integer()}
  @doc """
  convert a hex encoded string to int, or return int, if it's not string encoded
  return the desired error message, otherwise
  """
  def hex_to_int(value, err_msg) when is_bitstring(value) do
    case Integer.parse(value, 16) do
      {num, ""} ->
        {:ok, num}

      _ ->
        {:error, err_msg <> " , must be a hex encoded number, got: '#{inspect(value)}'"}
    end
  end

  def hex_to_int(value, _err_msg) when is_integer(value), do: {:ok, value}

  def hex_to_int(value, err_msg) do
    {:error, err_msg <> ", must be an int or a string, got: '#{inspect(value)}'"}
  end
end
