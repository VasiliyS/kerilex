import Derivation.Basic

pk = "BDno6jGtzjMdf5jvlo1qvbM8qIy6bSYb5xTPm5-2exLE" |> qb64_to_binary
sig = "0BBa7MYlvf2h6L32fjKN-Lv-5ox3OUSlkxfJB6-3Le6k4F7f8iixYsHZWv0TTn7-GLUlwW4C2z63U73wgQfcu8QK" |> qb64_to_binary
msg = "{\"v\":\"KERI10JSON00010d_\",\"t\":\"rpy\",\"d\":\"ECyo9nSwhlzhvPAK46-rYi4qYUy_mbNwJOn5Ex-Ac3f8\",\"dt\":\"2023-02-01T23:32:20.209420+00:00\",\"r\":\"/loc/scheme\",\"a\":{\"eid\":\"BDno6jGtzjMdf5jvlo1qvbM8qIy6bSYb5xTPm5-2exLE\",\"scheme\":\"http\",\"url\":\"http://witness1.stage.provenant.net:5631/\"}}"

Benchee.run(
  %{
    "enacl" => fn -> :enacl.sign_verify_detached(sig,msg,pk) end,
    "otp crypto" => fn -> :crypto.verify(:eddsa,:none,msg,sig,[pk, :ed25519],[]) end,
    "Ed25159  Elixir" => fn -> Ed25519.valid_signature?(sig,msg,pk) end
  },
  memory_time: 4
)
