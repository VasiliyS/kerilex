

keri_msg = ~S|{"v":"KERI10JSON00049d_","t":"icp","d":"EDP1vHcw_wc4M__Fj53-cJaBnZZASd-aMTaSyWEQ-PC2","i":"EDP1vHcw_wc4M__Fj53-cJaBnZZASd-aMTaSyWEQ-PC2","s":"0","kt":["1/3","1/3","1/3","1/3","1/3","1/3","1/3"],"k":["DFkI8OSUd9fnmdDM7wz9o6GT_pJIvw1K_S21AKZg4VwK","DA-vW9ynSkvOWv5e7idtikLANdS6pGO2IHJy7v0rypvE","DLWJrsKIHrrn1Q1jy2oEi8Bmv6aEcwuyIqgngVf2nNwu","DD6JYvXBsVAmEtirgwKPQBHFwVQfX4f_CZQmBsOh_1hT","DOOyxiELz2xqQCebeimJC4PW9Xv_5xgRkW7q_TC2lToN","DGoS9UZrs0u2jiCMlMGAG5xpUwQQ66NyqEoxmq8OiFUT","DBaAts7zYaRUNMkWIgWN5TL85cp61mHk_wlWzsIM-cc_"],"nt":["1/3","1/3","1/3","1/3","1/3","1/3","1/3"],"n":["EB_KZDNru1dlUb_Nk0EpxbU1ZDSNUO790RAZ_-ehCwR6","EHgOexUh8AvN7rXblsSr6MJE5Gn1HPq5Mv9KFpCpllKN","ECH4pTtUI653ykKb_capPBkKF3RvBZRzyb5dPfuJCfOf","ELXXiPwoaWOVOTLMOAmg4IKkjFHFs3q2hsL9tHvuuC2D","EAcNrjXFeGay9qqMj96FIiDdXqdWjX17QXzdJvq58Zco","ELzkbNYyJkwSa3HTua5eZwIeqiDmJBbUEgQ1a0sHtld_","EPoly9Tq4IPx41U-AGDShLDdtbFVzt7EqJUHmCrDxBdb"],"bt":"4","b":["BNfDO63ZpGc3xiFb0-jIOUnbr_bA-ixMva5cZb3s4BHB","BDwydI_FJJ-tvAtCl1tIu_VQqYTI3Q0JyHDhO1v2hZBt","BGYJwPAzjyJgsipO7GY9ZsBTeoUJrdzjI2w_5N-Nl6gG","BM4Ef3zlUzIAIx-VC8mXziIbtj-ZltM8Aor6TZzmTldj","BLo6wQR73-eH5v90at_Wt8Ep_0xfz05qBjM3_B1UtKbC"],"c":["EO"],"a":[]}|

keri_oo = Jason.decode!(keri_msg, objects: :ordered_objects)
keri_map = Watcher.KeyState.ordered_object_to_map(keri_oo)

Benchee.run(
  %{
  "conversion oo to map" => fn ->
    keri_map = Watcher.KeyState.ordered_object_to_map(keri_oo)
  end
},
  memory_time: 4
)

Benchee.run(
  %{
  "ordered obj" => fn ->
    keri_oo["c"]
  end,
  "keri_map" => fn ->
    keri_map["c"]
  end
},
memory_time: 4,
print: %{fast_warning: false}
)
