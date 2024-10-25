defmodule KelTestData.Kels do
  @moduledoc false
  alias Watcher.KeyStateCache

  def gleif_kel_july_23_24 do
    ks1 = %Watcher.KeyState{
      pe: "ECphNWm1_jZOupeKh6C7TlBi81BlERqbnMpyqpnS4CJY",
      te: "rot",
      se: 2,
      de: "EHsL1ldIafZC-M9-3RgLQB3m2_2F0aYIiNBGnTVoFDH2",
      fs: "2024-09-02T11:09:02.556481Z",
      k: [
        "DNLdWqTBKOhDO8YfE5uIaTvN-n_Jv20-5ZwK609BvG0b",
        "DL68G7IW4zT2ryLRDziYiRyvwIDyq9xssVuZ3u6w-30Y",
        "DH63RGGv_r8pQ5Di9MVblcofkBm0O8r6SUY0cqNAYqne"
      ],
      kt: %Kerilex.Crypto.WeightedKeyThreshold{
        size: 3,
        weights: [Ratio.new(1, 3), Ratio.new(1, 3), Ratio.new(1, 3)],
        sum: Ratio.new(1, 1),
        ind_ranges: [0..2]
      },
      n: [
        "EPHYDUnxDH7xcAim3aYvS9bvh7JmdBDKc__w2_McXr6I",
        "EHgOexUh8AvN7rXblsSr6MJE5Gn1HPq5Mv9KFpCpllKN",
        "ECH4pTtUI653ykKb_capPBkKF3RvBZRzyb5dPfuJCfOf",
        "ELXXiPwoaWOVOTLMOAmg4IKkjFHFs3q2hsL9tHvuuC2D",
        "EAcNrjXFeGay9qqMj96FIiDdXqdWjX17QXzdJvq58Zco",
        "EF1IPGq_uF3FmywFdIQXSO4jy0QhtzREVMlPQ8PEy_As",
        "EHGlZciB0cZ627-MJrQxyw5niNzN1nKnNMDaJO7sCEvF"
      ],
      nt: %Kerilex.Crypto.WeightedKeyThreshold{
        size: 7,
        weights: [
          Ratio.new(1, 3),
          Ratio.new(1, 3),
          Ratio.new(1, 3),
          Ratio.new(1, 3),
          Ratio.new(1, 3),
          Ratio.new(1, 3),
          Ratio.new(1, 3)
        ],
        sum: Ratio.new(7, 3),
        ind_ranges: [0..6]
      },
      b: [
        "BNfDO63ZpGc3xiFb0-jIOUnbr_bA-ixMva5cZb3s4BHB",
        "BDwydI_FJJ-tvAtCl1tIu_VQqYTI3Q0JyHDhO1v2hZBt",
        "BGYJwPAzjyJgsipO7GY9ZsBTeoUJrdzjI2w_5N-Nl6gG",
        "BM4Ef3zlUzIAIx-VC8mXziIbtj-ZltM8Aor6TZzmTldj",
        "BLo6wQR73-eH5v90at_Wt8Ep_0xfz05qBjM3_B1UtKbC"
      ],
      bt: 4,
      c: ["EO"],
      di: false,
      last_event: {"rot", 2, "EHsL1ldIafZC-M9-3RgLQB3m2_2F0aYIiNBGnTVoFDH2"}
    }

    ks2 = %Watcher.KeyState{
      pe: nil,
      te: "dip",
      se: 0,
      de: "EINmHd5g7iV-UldkkkKyBIH052bIyxZNBn9pq-zNrYoS",
      fs: "2024-09-02T11:09:02.563376Z",
      k: [
        "DEO7QT90CzPeCubjcAgDlYI-yudt0c_4HeAb1_RbrGiF",
        "DKu6Q_Qth7x-pztt11qXDr42B9aUjkp_v9Rq8-xXcQjF",
        "DEiPSxcuILZFxJscr_Lt8fuiidhB_HrqKxoCbZr9tQfp",
        "DIqrjqqwArsSHIX3n510DnSrYL9ULbYOpi14hEencBSC",
        "DAB9Tl0T8-638H65GMFj2G7CAr4CoExZ5xH-U1ADldFP"
      ],
      kt: %Kerilex.Crypto.WeightedKeyThreshold{
        size: 5,
        weights: [
          Ratio.new(1, 2),
          Ratio.new(1, 2),
          Ratio.new(1, 2),
          Ratio.new(1, 2),
          Ratio.new(1, 2)
        ],
        sum: Ratio.new(5, 2),
        ind_ranges: [0..4]
      },
      n: [
        "EObLskWwczY3R-ALRPWiyyThtraelnbh6MMeJ_WcR3Gd",
        "ENoI2e5f59xEF83joX__915Va-OIE7480wWyh2-8bJk7",
        "EElSAVDf2vU8aoxN50eSMNm6MrQ-Hv_2xOWC02tFrS3M",
        "EHX0Re-hExzl7mvLuRwQHEew-8oPOQh4rqXJNHBo9EyW",
        "EBGeYe1_ZgN_ly0qVY-Y1FayZkNA5Yq9LTujrh2ylKbm"
      ],
      nt: %Kerilex.Crypto.WeightedKeyThreshold{
        size: 5,
        weights: [
          Ratio.new(1, 2),
          Ratio.new(1, 2),
          Ratio.new(1, 2),
          Ratio.new(1, 2),
          Ratio.new(1, 2)
        ],
        sum: Ratio.new(5, 2),
        ind_ranges: [0..4]
      },
      b: [
        "BDkq35LUU63xnFmfhljYYRY0ymkCg7goyeCxN30tsvmS",
        "BLmvLSt1mDShWS67aJNP4gBVBhtOc3YEu8SytqVSsyfw",
        "BHxz8CDS_mNxAhAxQe1qxdEIzS625HoYgEMgqjZH_g2X",
        "BGYJwPAzjyJgsipO7GY9ZsBTeoUJrdzjI2w_5N-Nl6gG",
        "BFl6k3UznzmEVuMpBOtUUiR2RO2NZkR3mKrZkNRaZedo"
      ],
      bt: 4,
      c: [],
      di: "EDP1vHcw_wc4M__Fj53-cJaBnZZASd-aMTaSyWEQ-PC2",
      last_event: {"ixn", 8, "EDxDCjQoH82EgDEcSAU1SD__VKoebRUgr95nFweJxMgu"}
    }

    {"gleif-kel-july-23-24",
     KeyStateCache.new!([
       {"EDP1vHcw_wc4M__Fj53-cJaBnZZASd-aMTaSyWEQ-PC2", ks1},
       {"EINmHd5g7iV-UldkkkKyBIH052bIyxZNBn9pq-zNrYoS", ks2}
     ])}
  end

  def delegator_plus_2_ixn_dot_cesr do
    aid_delegator = "EHpD0-CDWOdu5RJ8jHBSUkOqBZ3cXeDVHWNb_Ul89VI7"
    aid_delegate = "EPCqFjBoALCddSFjYKDEPXgUIPsLTVaQsTSrnMHMuxdu"
    # simulating usage of a "stolen" key, rogue `ixn`s at sn=3,4

    # initial key state, after processing the "stolen" KEL
    delegator_ks1 = %Watcher.KeyState{
      pe: "EDrzTw3aqn-B6Hi9BO4KQ4gqX0eFj7FmubRoIhxxL9Ic",
      te: "rot",
      se: 2,
      de: "ED5as1z1RtK_v9r2g-uSijTNVCzeWdyNPidu3DtzAbSb",
      fs: nil,
      k: ["DH5oonAHXu45yAGMmt8eHOePMlGSiU-8lKHpjElUGW6o"],
      kt: %Kerilex.Crypto.KeyThreshold{threshold: 1},
      n: ["ED22-AGlgwyjJiSG-OwWsuV3U66bZPEeGbFata4XN6-1"],
      nt: %Kerilex.Crypto.KeyThreshold{threshold: 1},
      b: [
        "BBilc4-L3tFUnfM_wJr4S4OJanAv_VmF_dJNN6vkf2Ha",
        "BLskRTInXnMxWaGqcpSyMgo0nYbalW99cGZESrz3zapM",
        "BIKKuvBwpmDVA4Ds-EpL5bt9OqPzWPja2LigFYZN2YfX"
      ],
      bt: 3,
      c: [],
      di: false,
      last_event: {"ixn", 4, "EAkOi5TFMB-76gx3aLI8l2TAI9ar34J8bYo3P1rKaRly"}
    }

    delegate_ks1 = %Watcher.KeyState{
      pe: "EPCqFjBoALCddSFjYKDEPXgUIPsLTVaQsTSrnMHMuxdu",
      te: "drt",
      se: 1,
      de: "EEMbJ1Mo2SLyxLSepfeZ9qFWVAi3xpZDDIbbxp7Qz60N",
      fs: nil,
      k: ["DHxsk7rCkUB9OoUWS9oDBZT-NDeNzmfhuOGDd_f3VDad"],
      kt: %Kerilex.Crypto.KeyThreshold{threshold: 1},
      n: ["EEYBHa0cX6J4QTOknJC_x1ljuwF-9A2qOdKHFGI8ielb"],
      nt: %Kerilex.Crypto.KeyThreshold{threshold: 1},
      b: ["BBilc4-L3tFUnfM_wJr4S4OJanAv_VmF_dJNN6vkf2Ha"],
      bt: 1,
      c: [],
      di: "EHpD0-CDWOdu5RJ8jHBSUkOqBZ3cXeDVHWNb_Ul89VI7",
      last_event: {"drt", 1, "EEMbJ1Mo2SLyxLSepfeZ9qFWVAi3xpZDDIbbxp7Qz60N"}
    }

    {"delegator-plus-2-ixn.cesr",
     KeyStateCache.new!([{aid_delegator, delegator_ks1}, {aid_delegate, delegate_ks1}])}
  end

  def delegator_superseding_recovery_rot_at_3_dot_cesr() do
    # recovery at sn=3
    # delegator_kel_recovery = parse_kel("delegator-superseding-recovery-rot-at-3.cesr")
    aid_delegator = "EHpD0-CDWOdu5RJ8jHBSUkOqBZ3cXeDVHWNb_Ul89VI7"
    aid_delegate = "EPCqFjBoALCddSFjYKDEPXgUIPsLTVaQsTSrnMHMuxdu"
    # state after recovery
    delegator_ks2 = %Watcher.KeyState{
      pe: "ED5as1z1RtK_v9r2g-uSijTNVCzeWdyNPidu3DtzAbSb",
      te: "rot",
      se: 3,
      de: "ECNy4uJ3eihIcm7OUDGoUbAIKbk8fmRZSe8-Ydu8LwBW",
      fs: nil,
      k: ["DJoAuqZBLELpk9j0yiCvYXsSVBXhlTGPOLfZ_N4Hul2b"],
      kt: %Kerilex.Crypto.KeyThreshold{threshold: 1},
      n: ["EO48Bn9pXmIxGu3dwXLaGvzch_hiOexdfhn_mhbHU-Ef"],
      nt: %Kerilex.Crypto.KeyThreshold{threshold: 1},
      b: [
        "BBilc4-L3tFUnfM_wJr4S4OJanAv_VmF_dJNN6vkf2Ha",
        "BLskRTInXnMxWaGqcpSyMgo0nYbalW99cGZESrz3zapM",
        "BIKKuvBwpmDVA4Ds-EpL5bt9OqPzWPja2LigFYZN2YfX"
      ],
      bt: 3,
      c: [],
      di: false,
      last_event: {"rot", 3, "ECNy4uJ3eihIcm7OUDGoUbAIKbk8fmRZSe8-Ydu8LwBW"}
    }

    delegate_ks1 = %Watcher.KeyState{
      pe: "EPCqFjBoALCddSFjYKDEPXgUIPsLTVaQsTSrnMHMuxdu",
      te: "drt",
      se: 1,
      de: "EEMbJ1Mo2SLyxLSepfeZ9qFWVAi3xpZDDIbbxp7Qz60N",
      fs: nil,
      k: ["DHxsk7rCkUB9OoUWS9oDBZT-NDeNzmfhuOGDd_f3VDad"],
      kt: %Kerilex.Crypto.KeyThreshold{threshold: 1},
      n: ["EEYBHa0cX6J4QTOknJC_x1ljuwF-9A2qOdKHFGI8ielb"],
      nt: %Kerilex.Crypto.KeyThreshold{threshold: 1},
      b: ["BBilc4-L3tFUnfM_wJr4S4OJanAv_VmF_dJNN6vkf2Ha"],
      bt: 1,
      c: [],
      di: "EHpD0-CDWOdu5RJ8jHBSUkOqBZ3cXeDVHWNb_Ul89VI7",
      last_event: {"drt", 1, "EEMbJ1Mo2SLyxLSepfeZ9qFWVAi3xpZDDIbbxp7Qz60N"}
    }

    {"delegator-superseding-recovery-rot-at-3.cesr",
     KeyStateCache.new!([{aid_delegator, delegator_ks2}, {aid_delegate, delegate_ks1}])}
  end

  def delegator_3_ixn_plus_rot_at_6_dot_cesr do
    ks = %Watcher.KeyState{
      pe: "ENNf4zG4vJ_PysS_DC5RA2lZBOE1S1BYjwyOsZcNJHNJ",
      te: "rot",
      se: 6,
      de: "EMevUwpzVgGKOs6dwyj9LvdsldEdLoQ3m2Lz-34sB_th",
      fs: "2024-09-03T11:58:51.197445Z",
      k: ["DJoAuqZBLELpk9j0yiCvYXsSVBXhlTGPOLfZ_N4Hul2b"],
      kt: %Kerilex.Crypto.KeyThreshold{threshold: 1},
      n: ["EO48Bn9pXmIxGu3dwXLaGvzch_hiOexdfhn_mhbHU-Ef"],
      nt: %Kerilex.Crypto.KeyThreshold{threshold: 1},
      b: [
        "BBilc4-L3tFUnfM_wJr4S4OJanAv_VmF_dJNN6vkf2Ha",
        "BLskRTInXnMxWaGqcpSyMgo0nYbalW99cGZESrz3zapM",
        "BIKKuvBwpmDVA4Ds-EpL5bt9OqPzWPja2LigFYZN2YfX"
      ],
      bt: 3,
      c: [],
      di: false,
      last_event: {"rot", 6, "EMevUwpzVgGKOs6dwyj9LvdsldEdLoQ3m2Lz-34sB_th"}
    }

    {"delegator-3-ixn-plus-rot-at-6.cesr",
     KeyStateCache.new!([
       {"EHpD0-CDWOdu5RJ8jHBSUkOqBZ3cXeDVHWNb_Ul89VI7", ks}
     ])}
  end

  def delegator_plus_3_rot_changes_dot_cesr do
    ks = %Watcher.KeyState{
      pe: "EE5Gs3lv2kbxd4luv0-2JeLXTQBNlABy73EKMksDuggS",
      te: "rot",
      se: 7,
      de: "EPNFFu9E-vNDwnsikbigAsS2Yp7NjertxKJfERJjl9Tl",
      fs: "2024-09-03T13:30:37.730501Z",
      k: [
        "DF3_ATfnxuVzvIg-Ex5Ivc2we6DO_7maEhAtqU-57BBY",
        "DFAA-fCItgkNVFXfQiA9qD4pXOFOwztCT4owDJKUq18J"
      ],
      kt: %Kerilex.Crypto.KeyThreshold{threshold: 2},
      n: ["EL2g1gGN3UgDk9w75oTSvadCy_4saLRnLRuTBnlBGdRo"],
      nt: %Kerilex.Crypto.KeyThreshold{threshold: 1},
      b: [
        "BBilc4-L3tFUnfM_wJr4S4OJanAv_VmF_dJNN6vkf2Ha",
        "BIKKuvBwpmDVA4Ds-EpL5bt9OqPzWPja2LigFYZN2YfX",
        "BM35JN8XeJSEfpxopjn5jr7tAHCE5749f0OobhMLCorE"
      ],
      bt: 3,
      c: [],
      di: false,
      last_event: {"rot", 7, "EPNFFu9E-vNDwnsikbigAsS2Yp7NjertxKJfERJjl9Tl"}
    }

    {"delegator-plus-3-rot-changes.cesr",
     KeyStateCache.new!([
       {"EHpD0-CDWOdu5RJ8jHBSUkOqBZ3cXeDVHWNb_Ul89VI7", ks}
     ])}
  end

  def delegator_abandoned_dot_cesr do
    ks = %Watcher.KeyState{
      pe: "ED5as1z1RtK_v9r2g-uSijTNVCzeWdyNPidu3DtzAbSb",
      te: "rot",
      se: 3,
      de: "EPYxZMVFbU_1RwZAXA0-A_oKsw86T8zSCI3TF-xY37-x",
      fs: "2024-09-03T14:06:31.175408Z",
      k: ["DJoAuqZBLELpk9j0yiCvYXsSVBXhlTGPOLfZ_N4Hul2b"],
      kt: %Kerilex.Crypto.KeyThreshold{threshold: 1},
      n: [],
      nt: %Kerilex.Crypto.KeyThreshold{threshold: 0},
      b: [
        "BBilc4-L3tFUnfM_wJr4S4OJanAv_VmF_dJNN6vkf2Ha",
        "BLskRTInXnMxWaGqcpSyMgo0nYbalW99cGZESrz3zapM",
        "BIKKuvBwpmDVA4Ds-EpL5bt9OqPzWPja2LigFYZN2YfX"
      ],
      bt: 3,
      c: [],
      di: false,
      last_event: {"rot", 3, "EPYxZMVFbU_1RwZAXA0-A_oKsw86T8zSCI3TF-xY37-x"}
    }

    {"delegator-abandoned.cesr",
     KeyStateCache.new!([
       {"EHpD0-CDWOdu5RJ8jHBSUkOqBZ3cXeDVHWNb_Ul89VI7", ks}
     ])}
  end

  def provenant_oct_24_rot_new_keys do
    aid_gleif_root = "EDP1vHcw_wc4M__Fj53-cJaBnZZASd-aMTaSyWEQ-PC2"
    aid_gleif_geda = "EINmHd5g7iV-UldkkkKyBIH052bIyxZNBn9pq-zNrYoS"
    aid_provenant_qvi = "ED88Jn6CnWpNbSYz6vp9DOSpJH2_Di5MSwWTf1l34JJm"

    ks_gleif_root = %Watcher.KeyState{
      pe: "ECphNWm1_jZOupeKh6C7TlBi81BlERqbnMpyqpnS4CJY",
      te: "rot",
      se: 2,
      de: "EHsL1ldIafZC-M9-3RgLQB3m2_2F0aYIiNBGnTVoFDH2",
      fs: "2024-10-24T17:58:28.170581Z",
      k: ["DNLdWqTBKOhDO8YfE5uIaTvN-n_Jv20-5ZwK609BvG0b",
       "DL68G7IW4zT2ryLRDziYiRyvwIDyq9xssVuZ3u6w-30Y",
       "DH63RGGv_r8pQ5Di9MVblcofkBm0O8r6SUY0cqNAYqne"],
      kt: %Kerilex.Crypto.WeightedKeyThreshold{
        size: 3,
        weights: [Ratio.new(1, 3), Ratio.new(1, 3), Ratio.new(1, 3)],
        sum: Ratio.new(1, 1),
        ind_ranges: [0..2]
      },
      n: ["EPHYDUnxDH7xcAim3aYvS9bvh7JmdBDKc__w2_McXr6I",
       "EHgOexUh8AvN7rXblsSr6MJE5Gn1HPq5Mv9KFpCpllKN",
       "ECH4pTtUI653ykKb_capPBkKF3RvBZRzyb5dPfuJCfOf",
       "ELXXiPwoaWOVOTLMOAmg4IKkjFHFs3q2hsL9tHvuuC2D",
       "EAcNrjXFeGay9qqMj96FIiDdXqdWjX17QXzdJvq58Zco",
       "EF1IPGq_uF3FmywFdIQXSO4jy0QhtzREVMlPQ8PEy_As",
       "EHGlZciB0cZ627-MJrQxyw5niNzN1nKnNMDaJO7sCEvF"],
      nt: %Kerilex.Crypto.WeightedKeyThreshold{
        size: 7,
        weights: [Ratio.new(1, 3), Ratio.new(1, 3), Ratio.new(1, 3),
         Ratio.new(1, 3), Ratio.new(1, 3), Ratio.new(1, 3), Ratio.new(1, 3)],
        sum: Ratio.new(7, 3),
        ind_ranges: [0..6]
      },
      b: ["BNfDO63ZpGc3xiFb0-jIOUnbr_bA-ixMva5cZb3s4BHB",
       "BDwydI_FJJ-tvAtCl1tIu_VQqYTI3Q0JyHDhO1v2hZBt",
       "BGYJwPAzjyJgsipO7GY9ZsBTeoUJrdzjI2w_5N-Nl6gG",
       "BM4Ef3zlUzIAIx-VC8mXziIbtj-ZltM8Aor6TZzmTldj",
       "BLo6wQR73-eH5v90at_Wt8Ep_0xfz05qBjM3_B1UtKbC"],
      bt: 4,
      c: ["EO"],
      di: false,
      last_event: {"rot", 2, "EHsL1ldIafZC-M9-3RgLQB3m2_2F0aYIiNBGnTVoFDH2"}
    }

    ks_gleif_geda = %Watcher.KeyState{
      pe: nil,
      te: "dip",
      se: 0,
      de: "EINmHd5g7iV-UldkkkKyBIH052bIyxZNBn9pq-zNrYoS",
      fs: "2024-10-24T17:58:28.177890Z",
      k: ["DEO7QT90CzPeCubjcAgDlYI-yudt0c_4HeAb1_RbrGiF",
       "DKu6Q_Qth7x-pztt11qXDr42B9aUjkp_v9Rq8-xXcQjF",
       "DEiPSxcuILZFxJscr_Lt8fuiidhB_HrqKxoCbZr9tQfp",
       "DIqrjqqwArsSHIX3n510DnSrYL9ULbYOpi14hEencBSC",
       "DAB9Tl0T8-638H65GMFj2G7CAr4CoExZ5xH-U1ADldFP"],
      kt: %Kerilex.Crypto.WeightedKeyThreshold{
        size: 5,
        weights: [Ratio.new(1, 2), Ratio.new(1, 2), Ratio.new(1, 2),
         Ratio.new(1, 2), Ratio.new(1, 2)],
        sum: Ratio.new(5, 2),
        ind_ranges: [0..4]
      },
      n: ["EObLskWwczY3R-ALRPWiyyThtraelnbh6MMeJ_WcR3Gd",
       "ENoI2e5f59xEF83joX__915Va-OIE7480wWyh2-8bJk7",
       "EElSAVDf2vU8aoxN50eSMNm6MrQ-Hv_2xOWC02tFrS3M",
       "EHX0Re-hExzl7mvLuRwQHEew-8oPOQh4rqXJNHBo9EyW",
       "EBGeYe1_ZgN_ly0qVY-Y1FayZkNA5Yq9LTujrh2ylKbm"],
      nt: %Kerilex.Crypto.WeightedKeyThreshold{
        size: 5,
        weights: [Ratio.new(1, 2), Ratio.new(1, 2), Ratio.new(1, 2),
         Ratio.new(1, 2), Ratio.new(1, 2)],
        sum: Ratio.new(5, 2),
        ind_ranges: [0..4]
      },
      b: ["BDkq35LUU63xnFmfhljYYRY0ymkCg7goyeCxN30tsvmS",
       "BLmvLSt1mDShWS67aJNP4gBVBhtOc3YEu8SytqVSsyfw",
       "BHxz8CDS_mNxAhAxQe1qxdEIzS625HoYgEMgqjZH_g2X",
       "BGYJwPAzjyJgsipO7GY9ZsBTeoUJrdzjI2w_5N-Nl6gG",
       "BFl6k3UznzmEVuMpBOtUUiR2RO2NZkR3mKrZkNRaZedo"],
      bt: 4,
      c: [],
      di: "EDP1vHcw_wc4M__Fj53-cJaBnZZASd-aMTaSyWEQ-PC2",
      last_event: {"ixn", 8, "EDxDCjQoH82EgDEcSAU1SD__VKoebRUgr95nFweJxMgu"}
    }

    ks_provenant_qvi = %Watcher.KeyState{
      pe: "EC-6m6Ng36mYBLk0c2_wHxnD7bZQpbquBSUledELCeBf",
      te: "drt",
      se: 24,
      de: "EBD3Oyid3m2mRO7e_7JeoLzQe_GZE8WEbne2IMz3prwf",
      fs: "2024-10-24T17:58:28.182084Z",
      k: ["DCIFx-ddfBCOWTEXqVIxyUa76dea3b73JVbovfmq-6kz",
       "DD1w-uZAF22vPLMp4nzq_VQ918GGd6FdO0RbyLYly4Vb",
       "DMiOUvQa9hjGN8zv3NayvYG5yqGAcUVFf_q-SmVUiz7G",
       "DOX9KEk7dcPzy2VNvl699_Qq2-KML-MmYw6PPP2t1pUW",
       "DCxegeDmgcO-ma5G0iphkGfjJ-b6fC8OwZajgpDGuK-f",
       "DCw9XQLP0eBcSqIlAnsBujQsRroS-KLvRb4t5jTFLQ8C",
       "DAHePH7y_tv9tg2Rchvdzo5P67iimFJiL-wYQNDA34ur",
       "DJWc0cn27pUjBoBNf3cQgViWvcDUPOSWP7GCeHrZ5xno"],
      kt: %Kerilex.Crypto.WeightedKeyThreshold{
        size: 8,
        weights: [Ratio.new(0, 1), Ratio.new(0, 1), Ratio.new(0, 1),
         Ratio.new(0, 1), Ratio.new(1, 2), Ratio.new(1, 2), Ratio.new(1, 2),
         Ratio.new(1, 2)],
        sum: Ratio.new(2, 1),
        ind_ranges: [0..7]
      },
      n: ["EJ9MGn2MW0MP8o2mWUaLZmptgWH9rP3sKjGm43NtFKwl",
       "EFmAIIgfpwKLmmo3ruuneQAtt_MI3crleCFajPJxIO5S",
       "EPeofvCu0M5YyymqpsGexvBo0YI-DfnDOnWRZW0QqVrv",
       "ECvKPR7i5ZoeVJaB3UmyqLiYxVXDyDMdAwU1-t6uvukt"],
      nt: %Kerilex.Crypto.WeightedKeyThreshold{
        size: 4,
        weights: [Ratio.new(1, 2), Ratio.new(1, 2), Ratio.new(1, 2),
         Ratio.new(1, 2)],
        sum: Ratio.new(2, 1),
        ind_ranges: [0..3]
      },
      b: ["BNwSX8dtJ_Q-jlSIcgaL9phC2qT-PwNy_z1p-QSFPGMg",
       "BK5BgSYAzXvkzZU03-8Fo_eWoVdvlwQexGavi205MKQN",
       "BIHIg-sMesHIzbLzl8r9hq4797WZ8yKBidIKUKPrmEAk",
       "BLBC0dK4vnEEMa3Gw_P9_rHow6BRmU5lIXUqxdbEKWKk",
       "BOCWZuhoRHL_HpySDk450Shz2CNf9N5XNWmumlzvDGJj"],
      bt: 4,
      c: [],
      di: "EINmHd5g7iV-UldkkkKyBIH052bIyxZNBn9pq-zNrYoS",
      last_event: {"drt", 24, "EBD3Oyid3m2mRO7e_7JeoLzQe_GZE8WEbne2IMz3prwf"}
    }

    {"provenant-oct-24-rot-new-keys.cesr",
     KeyStateCache.new!([
       {aid_gleif_root, ks_gleif_root},
       {aid_gleif_geda, ks_gleif_geda},
       {aid_provenant_qvi, ks_provenant_qvi}
     ])}
  end

end
