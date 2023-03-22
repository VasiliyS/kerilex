

Benchee.run(
  %{
    "pure elixir" =>
    fn ->
      210
      |> Integer.to_string(16)
      |> String.downcase
      |> String.pad_leading(6,"0")
    end,
    "erlang io_lib" =>
    fn ->
      :io_lib.format("~6.16.0b", [210])
    end,
  },
  memory_time: 4
)
