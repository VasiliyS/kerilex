#!/bin/bash

curl_wit(){
curl -X POST \
-H "Content-Type: application/cesr+json" \
-H "Cesr-Attachment: $1" \
-d $2 \
127.0.0.1:5631
}

curl_wit \
'-VAu-AABAAAekwf1XAtwZ4tEV-sdSA2r-MZicUP-wyFh8gzPdpCS2eIu69dxd4Z6--NzMFsxFx2-w4IY41t-EUbGZHQDyDMH-BABAAD6rFSm5nE5DGC5glUoXCRKdpKhOp8iCJUEFmI5zkM4CFjgDbqQhoS1kxByLdVlVjD5cKP1Qp-NbVLruDDUTpgM' \
'{"v":"KERI10JSON00015d_","t":"icp","d":"EOyTxK8lZg8fVk_pT7Jv8sGpbCD_Rv3ME5-gJSHDGIX5","i":"EOyTxK8lZg8fVk_pT7Jv8sGpbCD_Rv3ME5-gJSHDGIX5","s":"0","kt":["1"],"k":["DNwaa7xNvGp_e7HI7MVu5z24NZSL3lpjyFzqGhZRdFFg"],"nt":["1"],"n":["EObuTbXuolMhr5CP8Ir8HtkW2rJTGzXfzHRCEiNJoVgs"],"bt":"1","b":["BI-Rfb-duERBvh6FuDkKHoZ5chsP2UQziONOrLLFfkgm"],"c":[],"a":[]}'