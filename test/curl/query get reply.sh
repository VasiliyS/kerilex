#!/bin/bash

curl_wit(){
curl -X POST \
-H "Content-Type: application/cesr+json" \
-H "Cesr-Attachment: $1" \
-d $2 \
127.0.0.1:5631
}

curl_wit \
"-VAj-HABEE_JGQw7kEYNBI-qY8QLXZimP9W5M-3lguOduY1w-v7y-AABAACzwFkdB5oFVxu162xTj05iA7CXAiDuQwsEMVxIMSqiw3K6zp_75ITk9cDRMEdcl3KU8yqWkCmBLF3Zzq2PRasL" \
'{"v":"KERI10JSON0000fe_","t":"qry","d":"EPyJD89rbjEKTxinm06bgtVMA_Ky62_IXK3tUXYGfljl","dt":"2023-04-02T20:26:50.887820+00:00","r":"ksn","rr":"","q":{"i":"EOyTxK8lZg8fVk_pT7Jv8sGpbCD_Rv3ME5-gJSHDGIX5","src":"BI7jE8sYGKsMoqzdflooeWrhU0Ecp5XJoY4V4cC-zyQy"}}'

sleep 2

curl_wit \
"-VAj-HABEE_JGQw7kEYNBI-qY8QLXZimP9W5M-3lguOduY1w-v7y-AABAAC827RGuLxRixPvqzcgew485AcqBR9dqFevTLjPHixkTut0zEy4SMlFDCSzPWzx5MPdIS3rVF86DmgmdAI0GgwM" \
'{"v":"KERI10JSON00014b_","t":"qry","d":"EFCszPnLUErzRJiKaeyTpJ3Ix0hJzcWHchq0vXtDXnc2","dt":"2023-04-02T20:27:11.891084+00:00","r":"mbx","rr":"","q":{"pre":"EE_JGQw7kEYNBI-qY8QLXZimP9W5M-3lguOduY1w-v7y","topics":{"/receipt":0},"i":"EE_JGQw7kEYNBI-qY8QLXZimP9W5M-3lguOduY1w-v7y","src":"BI7jE8sYGKsMoqzdflooeWrhU0Ecp5XJoY4V4cC-zyQy"}}'
