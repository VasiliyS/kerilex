gleif_witness = %{
  url: "http://65.21.253.212:5623",
  pre: "BDkq35LUU63xnFmfhljYYRY0ymkCg7goyeCxN30tsvmS"
}

{:ok, wc_geda} = Watcher.TransPreController.new("0AAhYttpeWnmDwLLiNiMk6mk") |> Watcher.TransPreController.incept_for(gleif_witness.pre)
geda_fin_talker = Watcher.WitnessTalker.new(gleif_witness.pre,gleif_witness.url)

Supervisor.start_link([geda_fin_talker |> Watcher.WitnessTalker.child_spec], strategy: :one_for_one)
geda_fin_talker |> Watcher.WitnessTalker.send_request(wc_geda.inception.serd_event, wc_geda.inception.att)

geda_pre = "EINmHd5g7iV-UldkkkKyBIH052bIyxZNBn9pq-zNrYoS"
{:ok, witness_mbx} = Kerilex.Event.Query.mbx(wc_geda.pre, geda_pre, geda_fin_talker.wit_pre,%{"reply" => 0, "replay"=>0, "receipt" => 0})
{:ok, witness_mbx_att} = Kerilex.Event.Query.sign_and_encode_to_cesr(wc_geda.pre, [wc_geda.signer], witness_mbx)

{:ok, wc_geda_mbx} = Kerilex.Event.Query.mbx(wc_geda.pre, wc_geda.pre, geda_fin_talker.wit_pre,%{"reply" => 0, "replay"=>0, "receipt" => 0})
{:ok, wc_geda_mbx_att} = Kerilex.Event.Query.sign_and_encode_to_cesr(wc_geda.pre, [wc_geda.signer], wc_geda_mbx)

geda_reg_id = "EM5S-xbxpG6qWG6doRcu9plZEVNexVliKgDQPASTb4rU"
qvi_vc_id ="EAeeixymEUsGcrmy0UZcS2y8PcYHkC_2G5D1qM0yGwpb"

# this doens't work - need to have vc_id !?
{:ok, ext_reg_qry_msg} = Kerilex.Event.Query.tels(geda_fin_talker.wit_pre, geda_reg_id)
{:ok, ext_reg_qry_msg_att} = Kerilex.Event.Query.sign_and_encode_to_cesr(wc_geda.pre, [wc_geda.signer], ext_reg_qry_msg)
geda_fin_talker |> Watcher.WitnessTalker.send_request(ext_reg_qry_msg, ext_reg_qry_msg_att)

{:ok, ext_reg_and_vc_qry_msg} = Kerilex.Event.Query.tels(geda_fin_talker.wit_pre, geda_reg_id, qvi_vc_id)
{:ok, ext_reg_and_vc_qry_msg_att} = Kerilex.Event.Query.sign_and_encode_to_cesr(wc_geda.pre, [wc_geda.signer], ext_reg_and_vc_qry_msg)
geda_fin_talker |> Watcher.WitnessTalker.send_request(ext_reg_and_vc_qry_msg, ext_reg_and_vc_qry_msg_att)
geda_fin_talker |> Watcher.WitnessTalker.stream_request(wc_geda_mbx, wc_geda_mbx_att)
