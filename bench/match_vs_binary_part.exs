
att1 = "-VDC-AADAABSSuY6EuzLJ9wHdPx8a6U8eLpKKknxOMd9aOAAJllt9dY6aTuk2HAP6T6Ed_OeMzTT5a_uTDM0RL7JX4-9eyENABAtHNdlPbe3-ZhpJdyid-iyyRJ_U4L9zxPdL2hmMHZPYhbUnhisXnE7mOcxEok7OPcuM_up6djQIVP7kMC0c1IAACCmzmcKNUp7zIHhtjIJNi4bIvCF-oRHXriDvEmFfLIo-87wSGe7puCth9NK4NNJADFGBDCpepJxKbPbD4yhevkB-BAFAABa132wXmJMgmgl9meWta9eqHU77tI6RbAFwVVLuFzDLxJuodK8bJeY1O-v_39IzwL8Dn6pUZkmybxwxvjLsWkAABBnD-Me6VjFL5OE2j0NwqSpqjVY3c5qmTcIqUZLMgCwudHCGza3gNlnSdt6TqYYYf_WQ9kXWCICMJjWgEsImgIOACDYJF1oHnu5bmkc1zPlj_DNvmBP6VkNbLC5r59BgmnI3_yloxfOy9-sln9WHTBEZpmter3lVvnXbGZlwbzmdv0FADA8O3q7KBx7BuzdSkFNUuX5U2YRw6xF12OY5rl2Tkx7xrVkqyaVybhxCQ-KU03QLup735MpaPDZ2XmBedF7_PAIAEC7BtU17WA4IqHApU4Mcp0IiTjnOJ-VLCi556iQc1Yq66Yy1jIM_UO0CQ2B9q_YEiQba7MTBRayPsyBgDYqq1AB-EAB0AAAAAAAAAAAAAAAAAAAAAAA1AAG2022-11-21T17c21c27d010057p00c00"

Benchee.run(
  %{
    "match bitstr head" => fn <<"-V",r::bitstring>> -> _ = r end,
    "match binary head" => fn <<"-V",_::binary>> ->   end,
    "match bitstr body" => fn att -> <<"-V",r::bitstring>> = att end,
    "match bitstr head and body" => fn <<att::bitstring>> -> <<"-V",r::bitstring>> = att end,
    "binary_part" => fn att ->
      code = binary_part(att,0,2)
      "-V" = code
    end

  },
  inputs: %{
    "with replay couples" => att1
  },
  memory_time: 4
)
