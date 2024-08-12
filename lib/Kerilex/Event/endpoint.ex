defmodule Kerilex.Event.Endpoint do
  import Comment
  alias Kerilex.Event
  alias Kerilex.DateTime, as: KDT
  alias Jason.OrderedObject, as: OO

  comment("""
  {
    "v": "KERI10JSON0000fa_",
    "t": "rpy",
    "d": "EJh9U0oZRJfbsoxXGL4yY7N4AF5m22rtbVKX4eDktPPJ",
    "dt": "2023-04-05T20:34:24.484202+00:00",
    "r": "/loc/scheme",
    "a": {
      "eid": "BP-nOCxB--MKSgwTXyLj01zA5jkG0Gb-8h-SHDX4qCJO",
      "scheme": "http",
      "url": "http://127.0.0.1:5631/"
    }
  } should be signed by the eid, i.e the backer/witness itself

  {
    "v": "KERI10JSON000116_",
    "t": "rpy",
    "d": "EPv7nBP5CrX1Oe9h2Vyp5xoxyn3I10JqL2-Exe0NBt4d",
    "dt": "2023-04-05T20:34:24.485337+00:00",
    "r": "/end/role/add",
    "a": {
      "cid": "BP-nOCxB--MKSgwTXyLj01zA5jkG0Gb-8h-SHDX4qCJO",
      "role": "controller",
      "eid": "BP-nOCxB--MKSgwTXyLj01zA5jkG0Gb-8h-SHDX4qCJO"
    }
  } not required for OOBI

  """)

  @spec event(any(), binary() | URI.t()) :: {:ok, binary()}
  def event(wit_pre, url) do
    uri = URI.parse(url)
    scheme = uri.scheme
    path = uri.path

    url =
      if String.ends_with?(path, "/") do
        url
      else
        url <> "/"
      end

    {:ok, eo} = event_obj(wit_pre, scheme, url)


    {:ok, msg, _said} =
    eo
    |> Event.serialize()

    {:ok, msg}
  end

  defp event_obj(eid, scheme, url) do
    att_vals = [
      eid: eid,
      scheme: scheme,
      url: url
    ]

    msg_vals = [
      v: Event.keri_version_str(),
      t: "rpy",
      d: "",
      dt: KDT.to_string(),
      r: "/loc/scheme",
      a: OO.new(att_vals)
    ]

    {:ok, OO.new(msg_vals)}
  end

  #################  signing ##############

  alias Kerilex.Crypto.Signer
  alias Kerilex.Attachment, as: Att
  alias Att.NonTransReceiptCouple, as: NTRC

  def sign(signer, msg) do
    {:ok, sig} = Signer.sign(signer, msg)
    ntrc = NTRC.new(signer.qb64, sig)
    {:ok, enc_couples} = Att.NonTransReceiptCouples.encode([ntrc])

    Att.encode(enc_couples)
  end
end
