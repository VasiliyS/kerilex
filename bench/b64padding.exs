
Benchee.run(
  %{
   "prefix compare version"    => fn ->  2 ** 25-1    |> Attachment.Number.b64_padding end,
    "calc version" => fn -> 2 ** 25-1    |> Attachment.Number.int_to_b64_padding end,
  },
  memory_time: 4
)
