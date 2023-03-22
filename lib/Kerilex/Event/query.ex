defmodule Kerilex.Event.Query do
  @moduledoc """
    defines Query Event, which is used to interrogate witnesses
  """

  import Kerilex.Constants
  import Comment
  alias Kerilex.Event.Common, as: Events
  alias Kerilex.DateTime, as: KDT

  comment("""
    examples of query messages:

    request a kel, verify that anchor ( optional) and sn are present at the witness
    {
        "v" : "KERI10JSON00011c_",
        "t" : "qry",
        "d":"ECN0WOpvJd1-PFIylLURxnq_q18-gKq3OAzI-FyCV8Xg",
        "dt": "2023-03-08T17:49:43.822133+00:00",
        "r" : "logs",
        "rr": "log/processor",
        "q" :
        {
          "i":  "EaU6JR2nmwyZ-i0d8JZAoTNZH3ULvYAfSVPzhzS6b5CM", <- req, prefix whose events will be searched
          "s": "5", <- optional, will make sure that existing kel is at least at this seq num
          "src": "BEXBtyNmAdUiEMsPYamGdMq4TEQfmitcFAyUYcY15Im2" <- req, witness pref
          "a": <- optional, find an event of the "i" prefix, which has the following anchor ( event seal)
          {
            "i": "EaU6JR2nmwyZ-i0d8JZAoTNZH3ULvYAfSVPzhzS6b5CM",
            "s": "3",
            "d": "EKfOZZJHPIPS2hOXGt5oUHYbZviHEW122YX8Quf7GWA2"
          }
        }
      }
    }

    get key state message

    {
    "v": "KERI10JSON00014b_",
    "t": "qry",
    "d": "ECN0WOpvJd1-PFIylLURxnq_q18-gKq3OAzI-FyCV8Xg",
    "dt": "2023-03-07T20:52:44.034736+00:00",
    "r": "ksn",
    "rr": "", <- not used, replay route will be /ksn/{src}
    "q": {
      "i": "EAR1eNUllla9Y7l0ru0btqGrFoWuhLk8BkMWFUMEljUY", <- the prefix to get state for
      "src": "BEXBtyNmAdUiEMsPYamGdMq4TEQfmitcFAyUYcY15Im2" <- witness providing the state
    }


    get requested (ksn or logs query )response, witness will send the response as an SSE

    {
    "v": "KERI10JSON00014b_",
    "t": "qry",
    "d": "ECN0WOpvJd1-PFIylLURxnq_q18-gKq3OAzI-FyCV8Xg",
    "dt": "2023-03-07T20:52:44.034736+00:00",
    "r": "mbx",
    "rr": "", <- will be copied into response message
    "q": {
      "pre": "EAR1eNUllla9Y7l0ru0btqGrFoWuhLk8BkMWFUMEljUY",
      "topics": {
        "/receipt": 7 <- get this type of reply at this index.
      },
      "i": "EAR1eNUllla9Y7l0ru0btqGrFoWuhLk8BkMWFUMEljUY",
      "src": "BEXBtyNmAdUiEMsPYamGdMq4TEQfmitcFAyUYcY15Im2"
    }




  """)

  const(ilk, "qry")

  def ksn(pre, src) do
    query_obj =
      [i: pre, src: src]
      |> Jason.OrderedObject.new()

    msg_vals = [
      v: Events.keri_version_str(),
      t: ilk(),
      d: "",
      dt: KDT.to_string(),
      r: "ksn",
      rr: "",
      q: query_obj
    ]

    Jason.OrderedObject.new(msg_vals)
  end

  def mbx(req_pre, subj_pre, wit_pre, %{} = topics, rr \\ "") do

    topics_obj =
      topics
      |> Enum.reduce(
        [],
        fn {t,idx} , tpcs ->
          k = String.to_atom("/" <> t)
          [{k, idx} | tpcs]
        end
      )
      |> Jason.OrderedObject.new()

    query_obj =
      [
        pre: req_pre,
        topics: topics_obj,
        i: subj_pre,
        src: wit_pre
      ]
      |> Jason.OrderedObject.new()

    msg_vals = [
      v: Events.keri_version_str(),
      t: ilk(),
      d: "",
      dt: KDT.to_string(),
      r: "mbx",
      rr: rr,
      q: query_obj
    ]

    Jason.OrderedObject.new(msg_vals)
  end
end
