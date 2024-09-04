alias Kerilex.KELParser

serd_msg = %{serd_msg: ~S|{"v":"KERI10JSON0003f9_","t":"dip","d":"EINmHd5g7iV-UldkkkKyBIH052bIyxZNBn9pq-zNrYoS","i":"EINmHd5g7iV-UldkkkKyBIH052bIyxZNBn9pq-zNrYoS","s":"0","kt":["1/2","1/2","1/2","1/2","1/2"],"k":["DEO7QT90CzPeCubjcAgDlYI-yudt0c_4HeAb1_RbrGiF","DKu6Q_Qth7x-pztt11qXDr42B9aUjkp_v9Rq8-xXcQjF","DEiPSxcuILZFxJscr_Lt8fuiidhB_HrqKxoCbZr9tQfp","DIqrjqqwArsSHIX3n510DnSrYL9ULbYOpi14hEencBSC","DAB9Tl0T8-638H65GMFj2G7CAr4CoExZ5xH-U1ADldFP"],"nt":["1/2","1/2","1/2","1/2","1/2"],"n":["EObLskWwczY3R-ALRPWiyyThtraelnbh6MMeJ_WcR3Gd","ENoI2e5f59xEF83joX__915Va-OIE7480wWyh2-8bJk7","EElSAVDf2vU8aoxN50eSMNm6MrQ-Hv_2xOWC02tFrS3M","EHX0Re-hExzl7mvLuRwQHEew-8oPOQh4rqXJNHBo9EyW","EBGeYe1_ZgN_ly0qVY-Y1FayZkNA5Yq9LTujrh2ylKbm"],"bt":"4","b":["BDkq35LUU63xnFmfhljYYRY0ymkCg7goyeCxN30tsvmS","BLmvLSt1mDShWS67aJNP4gBVBhtOc3YEu8SytqVSsyfw","BHxz8CDS_mNxAhAxQe1qxdEIzS625HoYgEMgqjZH_g2X","BGYJwPAzjyJgsipO7GY9ZsBTeoUJrdzjI2w_5N-Nl6gG","BFl6k3UznzmEVuMpBOtUUiR2RO2NZkR3mKrZkNRaZedo"],"c":[],"a":[],"di":"EDP1vHcw_wc4M__Fj53-cJaBnZZASd-aMTaSyWEQ-PC2"}|}

Benchee.run(
  %{
    "check msg integrity" => fn -> serd_msg |> KELParser.check_msg_integrity end,

  },
  memory_time: 4,
  profile_after: true
)
