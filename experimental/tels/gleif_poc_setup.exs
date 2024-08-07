{:ok, wc} = Watcher.TransPreController.new("0AAhYttpeWnmDwLLiNiMk6mk") |> Watcher.TransPreController.incept_for("BBilc4-L3tFUnfM_wJr4S4OJanAv_VmF_dJNN6vkf2Ha")
wan_talker = Watcher.WitnessTalker.new("BBilc4-L3tFUnfM_wJr4S4OJanAv_VmF_dJNN6vkf2Ha","http://192.168.2.209:5642")

Supervisor.start_link([wan_talker |> Watcher.WitnessTalker.child_spec], strategy: :one_for_one)
wan_talker |> Watcher.WitnessTalker.send_request(wc.inception.serd_event, wc.inception.att)

wan_ctrl = Watcher.TransPreController.new("0ACDEyMzQ1Njc4OWxtbm9GhI","external")
wan_ctrl = %{ wan_ctrl | pre: "EHOuGiHMxJShXHgSb6k_9pqxmRb8H-LT0R2hQouHp8pW"}

{:ok, vcp} = Kerilex.Event.Tel.vcp_nonce("EHOuGiHMxJShXHgSb6k_9pqxmRb8H-LT0R2hQouHp8pW", ["NB"], "0ABVU7_dwQ6GPL5bS3xH8wVG")
{:ok, vcp_att} = Kerilex.Event.Tel.att_sign_and_add_seal_source_couple(wan_ctrl.pre, [wan_ctrl.signer], vcp, 1, "EKQ0rTOGHsf8HpunpgdWIhFLUYKF5qW1DqJRJTOse7iF")
wan_talker |> Watcher.WitnessTalker.send_request(vcp, vcp_att)

{:ok, external_mbx} = Kerilex.Event.Query.mbx(wc.pre, wc.pre, wan_talker.wit_pre,%{"reply" => 0, "replay"=>0, "receipt" => 0})
{:ok, external_mbx_att} = Kerilex.Event.Query.sign_and_encode_to_cesr(wc.pre, [wc.signer], external_mbx)

external_reg_id = "EPJ7a5weXruYV_q-RzQuLtr-dVReQXE7GdNbZrA3qw4y"
qvi_vc_id = "EMmnWFP7hHiwYewEryd4P33WtZckTWcUc-V67LjGlGnD"

{:ok, ext_reg_qry_msg} = Kerilex.Event.Query.tels(wan_talker.wit_pre, external_reg_id)
{:ok, ext_reg_qry_msg_att} = Kerilex.Event.Query.sign_and_encode_to_cesr(wc.pre, [wc.signer], ext_reg_qry_msg)
wan_talker |> Watcher.WitnessTalker.send_request(ext_reg_qry_msg, ext_reg_qry_msg_att)

{:ok, ext_vci_qry_msg} = Kerilex.Event.Query.tels(wan_talker.wit_pre, "", qvi_vc_id)
{:ok, ext_vci_qry_msg_att} = Kerilex.Event.Query.sign_and_encode_to_cesr(wc.pre, [wc.signer], ext_reg_qry_msg)
wan_talker |> Watcher.WitnessTalker.send_request(ext_vci_qry_msg, ext_vci_qry_msg_att)


{:ok, ext_reg_and_vc_qry_msg} = Kerilex.Event.Query.tels(wan_talker.wit_pre, external_reg_id, qvi_vc_id)
{:ok, ext_reg_and_vc_qry_msg_att} = Kerilex.Event.Query.sign_and_encode_to_cesr(wc.pre, [wc.signer], ext_reg_and_vc_qry_msg)
wan_talker |> Watcher.WitnessTalker.send_request(ext_reg_and_vc_qry_msg, ext_reg_and_vc_qry_msg_att)

{:ok, tsn_qry} = Kerilex.Event.Query.tsn(wan_talker.wit_pre, external_reg_id, qvi_vc_id)
{:ok, tsn_qry_att} = Kerilex.Event.Query.sign_and_encode_to_cesr(wc.pre, [wc.signer], tsn_qry)
wan_talker |> Watcher.WitnessTalker.send_request(tsn_qry, tsn_qry_att)
{:ok, rsp} = wan_talker |> Watcher.WitnessTalker.poll_mbx(external_mbx, external_mbx_att)


{:ok, logs_qry} = Kerilex.Event.Query.logs(wc.pre, wc.pre, wan_talker.wit_pre, "logs/" <> wc.pre, 1)
{:ok, logs_qry_att} = Kerilex.Event.Query.sign_and_encode_to_cesr(wc.pre, [wc.signer], logs_qry)
wan_talker |> Watcher.WitnessTalker.send_request(logs_qry, logs_qry_att)
