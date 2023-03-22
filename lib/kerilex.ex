defmodule Kerilex do
  @moduledoc """
  Documentation for `Kerilex`.
  """

  @doc """

  ## Examples

  """
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
        '',
        fn _, acc ->
          [char | acc]
        end
      )

    List.to_string(lst)
  end
end
