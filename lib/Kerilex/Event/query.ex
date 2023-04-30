defmodule Kerilex.Event.Query do
  @moduledoc """
    defines Query Event, which is used to interrogate witnesses
  """

  import Kerilex.Constants
  import Comment
  alias Kerilex.Event
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
        "rr": "log/processor", <- this is user defined, will be copied to the `rpy` receipt
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
    "rr": "", <- not used, reply route will be /ksn/{src}
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
    "rr": "", <- will be copied into the response message
    "q": {
      "pre": "EAR1eNUllla9Y7l0ru0btqGrFoWuhLk8BkMWFUMEljUY",
      "topics": {
        "/receipt": 7 <- get this type of reply at this index.
      },
      "i": "EAR1eNUllla9Y7l0ru0btqGrFoWuhLk8BkMWFUMEljUY", <- subject of the query
      "src": "BEXBtyNmAdUiEMsPYamGdMq4TEQfmitcFAyUYcY15Im2" <- witness's prefix
    }

    {
      "v": "KERI10JSON000162_",
      "t": "qry",
      "d": "ED8gL5oQQUCJ10X219TlMRVU2ROkx6R7_jRHe7_1VcPx",
      "dt": "2023-04-05T19:59:24.268841+00:00",
      "r": "mbx",
      "rr": "",
      "q": {
        "pre": "ECiTx4B-xr0XDsxGB2iQwPT7GrhPz7t7bnIZO-SbdOxg",
        "topics": {
          "/receipt": 0,
          "/replay": 0,
          "/reply": 0
        },
        "i": "ECiTx4B-xr0XDsxGB2iQwPT7GrhPz7t7bnIZO-SbdOxg",
        "src": "BP-nOCxB--MKSgwTXyLj01zA5jkG0Gb-8h-SHDX4qCJO"
      }
    }



  """)

  const(ilk, "qry")

  def ksn(asking_pre, subj_pre, wit_pre) do
    query_obj =
      [pre: asking_pre, i: subj_pre, src: wit_pre]
      |> Jason.OrderedObject.new()

    to_ordered_object("ksn", "", query_obj)
  end

  def logs(asking_pre, subj_pre, wit_pre, rr \\ "", s \\ nil, event_seal \\ [])
      when is_list(event_seal) do
    sn =
      if s != nil do
        sn = s |> Integer.to_string(16) |> String.downcase()
        [s: sn]
      else
        []
      end

    a =
      if length(event_seal) > 0 do
        [a: event_seal |> Jason.OrderedObject.new()]
      else
        []
      end

    query_obj =
      ([pre: asking_pre, i: subj_pre] ++ sn ++ [src: wit_pre] ++ a)
      |> Jason.OrderedObject.new()

    to_ordered_object("logs", rr, query_obj)
  end

  def mbx(req_pre, subj_pre, wit_pre, %{} = topics, rr \\ "") do
    topics_obj =
      topics
      |> Enum.reduce(
        [],
        fn {t, idx}, tpcs ->
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

    to_ordered_object("mbx", rr, query_obj)
  end

  defp to_ordered_object(route, return_route, qry_obj) do
    [
      v: Event.keri_version_str(),
      t: ilk(),
      d: "",
      dt: KDT.to_string(),
      r: route,
      rr: return_route,
      q: qry_obj
    ]
    |> Jason.OrderedObject.new()
    |> Event.serialize()
    |> case do
      {:ok, serd_msg, _said} ->
        {:ok, serd_msg}

      {:error, reason} ->
        {:error, "failed to encode qry msg: #{reason}"}
    end
  end

  #################  signing ##############

  alias Kerilex.Crypto.Signer
  alias Kerilex.Attachment, as: Att
  alias Att.TransLastIdxSigGroups, as: TLISG

  def sign(pre, signers, qry_msg) when is_list(signers) do
    ctrl_sigs =
      for {s, ind} <- Enum.with_index(signers), into: [] do
        {:ok, sig} = Signer.sign(s, qry_msg)
        %Att.IndexedControllerSig{sig: sig, ind: ind}
      end

    # {:ok, idx_ctrl_sigs} = Att.IndexedControllerSigs.encode(ctrl_sigs)

    {:ok, tr_last_idx_sigs_group} = [{pre, ctrl_sigs}] |> TLISG.encode()

    Att.encode(tr_last_idx_sigs_group |> IO.inspect(label: "enc_groups"))
  end

  def sign(signer, qry_msg) do
    {:ok, sig} = Signer.sign(signer, qry_msg)
    #ctrl_sig = %Att.IndexedControllerSig{sig: sig, ind: 0}
    #{:ok, idx_ctrl_sigs} = Att.IndexedControllerSigs.encode([ctrl_sig])
    receipt_couple = %Att.NonTransReceiptCouple{pre: signer.qb64, sig: sig}
    {:ok, enc_couples} = Att.NonTransReceiptCouples.encode([receipt_couple])

    Att.encode(enc_couples)
  end
end
