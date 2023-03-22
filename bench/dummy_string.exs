import Kerilex

Benchee.run(
  %{
    "list" => fn -> dummy_string(?#,44) end,
    "string reduce" => fn -> Enum.reduce(1..44, "", fn _, acc -> "#" <> acc end) end,
    "string duplicate" => fn -> String.duplicate("#",44) end
  },
  memory_time: 4
)
