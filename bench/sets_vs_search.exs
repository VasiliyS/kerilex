
rot_labels = ["v", "i", "s", "t", "p", "kt", "k", "n", "bt", "br", "ba", "a"]
dip_labels = ["v", "i", "s", "t", "kt", "k", "n", "bt", "b", "c", "a", "di"]
dip_labels_set = :sets.from_list(dip_labels, version: 2)
rot_labels_set = :sets.from_list(rot_labels, version: 2)

serd_msg = ~S|{"v":"KERI10JSON0003f9_","t":"dip","d":"EINmHd5g7iV-UldkkkKyBIH052bIyxZNBn9pq-zNrYoS","i":"EINmHd5g7iV-UldkkkKyBIH052bIyxZNBn9pq-zNrYoS","s":"0","kt":["1/2","1/2","1/2","1/2","1/2"],"k":["DEO7QT90CzPeCubjcAgDlYI-yudt0c_4HeAb1_RbrGiF","DKu6Q_Qth7x-pztt11qXDr42B9aUjkp_v9Rq8-xXcQjF","DEiPSxcuILZFxJscr_Lt8fuiidhB_HrqKxoCbZr9tQfp","DIqrjqqwArsSHIX3n510DnSrYL9ULbYOpi14hEencBSC","DAB9Tl0T8-638H65GMFj2G7CAr4CoExZ5xH-U1ADldFP"],"nt":["1/2","1/2","1/2","1/2","1/2"],"n":["EObLskWwczY3R-ALRPWiyyThtraelnbh6MMeJ_WcR3Gd","ENoI2e5f59xEF83joX__915Va-OIE7480wWyh2-8bJk7","EElSAVDf2vU8aoxN50eSMNm6MrQ-Hv_2xOWC02tFrS3M","EHX0Re-hExzl7mvLuRwQHEew-8oPOQh4rqXJNHBo9EyW","EBGeYe1_ZgN_ly0qVY-Y1FayZkNA5Yq9LTujrh2ylKbm"],"bt":"4","b":["BDkq35LUU63xnFmfhljYYRY0ymkCg7goyeCxN30tsvmS","BLmvLSt1mDShWS67aJNP4gBVBhtOc3YEu8SytqVSsyfw","BHxz8CDS_mNxAhAxQe1qxdEIzS625HoYgEMgqjZH_g2X","BGYJwPAzjyJgsipO7GY9ZsBTeoUJrdzjI2w_5N-Nl6gG","BFl6k3UznzmEVuMpBOtUUiR2RO2NZkR3mKrZkNRaZedo"],"c":[],"a":[],"di":"EDP1vHcw_wc4M__Fj53-cJaBnZZASd-aMTaSyWEQ-PC2"}|


#json = ~S|{"v":"v", "i":"i", "s":"s", "t":"t", "p":"p", "kt":"kt", "k":"k", "n":"n", "bt":"bt", "br":"br", "ba":"ba", "a":"a"}|

small_dip_obj =
dip_labels
|> Enum.with_index(
  fn el, idx ->
    [~s|"#{el}":|, "#{idx}"]
  end
)
|> Enum.intersperse(",")
|> then(&["{",&1,"}"])
|> IO.iodata_to_binary()
|> Jason.decode!(objects: :ordered_objects)

keri_dip_obj = serd_msg |> Jason.decode!(objects: :ordered_objects)

compare_with_sets =
  fn {pased_obj, labels_set} ->
    obj_lset =
      pased_obj.values
      |> Enum.reduce(:sets.new(version: 2), fn {k,_v}, lset -> :sets.add_element(k, lset) end)

      :sets.is_subset(labels_set, obj_lset)

  end

true = compare_with_sets.({small_dip_obj, dip_labels_set})
false = compare_with_sets.({small_dip_obj, rot_labels_set})

compare_with_reduce =
  fn {parsed_obj, labels} ->
    labels
    |> Enum.reduce_while(
      false,
      fn l, _res ->
        if parsed_obj[l] != nil , do: {:cont, true}, else: {:halt, {:missing_label, l}}
      end
    )
  end

true = compare_with_reduce.({small_dip_obj, dip_labels})
{:missing_label, _l} = compare_with_reduce.({small_dip_obj, rot_labels})

Benchee.run(%{
  "compare labels with sets" =>
    {
      compare_with_sets,
      before_scenario: fn {obj, labels} ->

        lset = :sets.from_list(labels, version: 2)
        {obj, lset}
    end
    },
  "compare labels with reduce" => compare_with_reduce
},
inputs: %{
  "small dip json, dip labels" => {small_dip_obj, dip_labels},
  "small dip json, rot labels" => {small_dip_obj, rot_labels},
  "keri dip message, dip labels" => {keri_dip_obj, dip_labels},
  "keri dip message, rot labels" => {keri_dip_obj, rot_labels},
},
memory_time: 4,
reduction_time: 2)
