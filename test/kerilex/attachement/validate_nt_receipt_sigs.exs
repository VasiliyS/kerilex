defmodule Kerilex.Attachment.NTRcptCouplesTest do
  use ExUnit.Case

  @valid_msg ~S|{"v":"KERI10JSON0000fe_","t":"rpy","d":"EL8v2q-zLbCqPV4TX2eHLTlhjlcGxb7JUI_33DZo8Zhl","dt":"2023-02-22T11:54:23.468058+00:00","r":"/loc/scheme","a":{"eid":"BDkq35LUU63xnFmfhljYYRY0ymkCg7goyeCxN30tsvmS","scheme":"http","url":"http://65.21.253.212:5623/"}}-VAi-CABBDkq35LUU63xnFmfhljYYRY0ymkCg7goyeCxN30tsvmS0BA0fNn0QdsoBXG5B2V6_h-dAfVG5cXm6Hg0pZ0mIT-5nHoQKnDTvt6M95hft0ONsMftVZuG9RuYt0jMlvw2Ea0C|
  @invalid_pref ~S|{"v":"KERI10JSON0000fe_","t":"rpy","d":"EL8v2q-zLbCqPV4TX2eHLTlhjlcGxb7JUI_33DZo8Zhl","dt":"2023-02-22T11:54:23.468058+00:00","r":"/loc/scheme","a":{"eid":"BDkq35LUU63xnFmfhljYYRY0ymkCg7goyeCxN30tsvmS","scheme":"http","url":"http://65.21.253.212:5623/"}}-VAi-CABBDkq35LUU63xnFmfhljYYRY0ymkCc7goyeCxN30tsvmS0BA0fNn0QdsoBXG5B2V6_h-dAfVG5cXm6Hg0pZ0mIT-5nHoQKnDTvt6M95hft0ONsMftVZuG9RuYt0jMlvw2Ea0C|
  @invalid_sig ~S|{"v":"KERI10JSON0000fe_","t":"rpy","d":"EL8v2q-zLbCqPV4TX2eHLTlhjlcGxb7JUI_33DZo8Zhl","dt":"2023-02-22T11:54:23.468058+00:00","r":"/loc/scheme","a":{"eid":"BDkq35LUU63xnFmfhljYYRY0ymkCg7goyeCxN30tsvmS","scheme":"http","url":"http://65.21.253.212:5623/"}}-VAi-CABBDkq35LUU63xnFmfhljYYRY0ymkCg7goyeCxN30tsvmS0BA0fNn1QdsoBXG5B2V6_h-dAfVG5cXm6Hg0pZ0mIT-5nHoQKnDTvt6M95hft0ONsMftVZuG9RuYt0jMlvw2Ea0C|

  alias Kerilex.Attachment, as: Att
  alias Kerilex.KEL

  setup do
    keri_msg = @valid_msg |> KEL.parse() |> hd
    inv_pref_msg = @invalid_pref |> KEL.parse() |> hd
    inv_sig_msg = @invalid_sig |> KEL.parse() |> hd

    {:ok,
     %{
       val_keri_msg: keri_msg,
       inv_pref_msg: inv_pref_msg,
       inv_sig_msg:  inv_sig_msg
     }}
  end

  def check_sigs(keri_msg) do
    rc = Map.fetch!(keri_msg, Att.nt_rcpt_couples())
    serd_msg = Map.fetch!(keri_msg, :serd_msg)
    Att.NonTransReceiptCouples.check(rc, serd_msg)
  end

  test "signature for NonTransReceiptCouple is correct", %{val_keri_msg: keri_msg} do
    assert check_sigs(keri_msg) == :ok
  end

  test "bad pref fails sig check", %{inv_pref_msg: keri_msg} do
    {:error, reason} = check_sigs(keri_msg)

    assert reason == "NonTransReceiptCouple idx: 0 failed sig check"
  end

  test "bad sig fails sig check", %{inv_sig_msg: keri_msg} do
    {:error, reason} = check_sigs(keri_msg)

    assert reason == "NonTransReceiptCouple idx: 0 failed sig check"
  end
end
