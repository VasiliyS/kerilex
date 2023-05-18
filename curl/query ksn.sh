#!/bin/bash

curl_wit(){
curl -X POST \
-H "Content-Type: application/cesr+json" \
-H "Cesr-Attachment: $1" \
-d $2 \
127.0.0.1:5631
}

curl_wit \
"-VAj-HABEE_JGQw7kEYNBI-qY8QLXZimP9W5M-3lguOduY1w-v7y-AABAACPLJPH4wpB3SlbkT0ZVsTL4j0vxAwnCiWw4IKLvWvk1o9-DVLHU2A3kE3nJxk8j9RPE3bdXaxnlpKwc_MH9awE" \
'{"v":"KERI10JSON000133_","t":"qry","d":"EH-O97ShmbjXMU61Jhp3usEjBs0Z_J5nvoC6AZ-vtNzG","dt":"2023-04-05T20:17:29.268100+00:00","r":"ksn","rr":"","q":{"pre":"EE_JGQw7kEYNBI-qY8QLXZimP9W5M-3lguOduY1w-v7y","i":"ECiTx4B-xr0XDsxGB2iQwPT7GrhPz7t7bnIZO-SbdOxg","src":"BP-nOCxB--MKSgwTXyLj01zA5jkG0Gb-8h-SHDX4qCJO"}}'
