#!/bin/bash

curl_wit(){
curl -X POST \
-H "Content-Type: application/cesr+json" \
-H "Cesr-Attachment: $1" \
-d $2 \
127.0.0.1:5631
}

curl_wit \
"-VAi-CABBPeRyrgFEUIDbtcKL-urikCsy9VaZ_RH1fPQhNwWOCj00BD-LlUzzrjEg4onTNTs9GoqI08RdqchxpV3Khp8BJYCfy0DAyb0N6i6A4xNc2WNEy8Ky0HyElsi2I4POCnX1XUO" \
'{"v":"KERI10JSON0000fe_","t":"qry","d":"EAKQFzPGnkeNBX3dsUV3dDkTX-5i_NCXTpIavD2BA7Vo","dt":"2023-03-10T20:48:47.331155+00:00","r":"ksn","rr":"","q":{"i":"EAR1eNUllla9Y7l0ru0btqGrFoWuhLk8BkMWFUMEljUY","src":"BEXBtyNmAdUiEMsPYamGdMq4TEQfmitcFAyUYcY15Im2"}}'

sleep 2

curl_wit \
"-VAi-CABBPeRyrgFEUIDbtcKL-urikCsy9VaZ_RH1fPQhNwWOCj00BAd7AfpXUontdg8wXQfyIFujErrfuza2kzsh0zGdmR6_J7FuJr6DZI1sj0a6UOebuzhdI2HJL6n0TChUoimQFoF" \
'{"v":"KERI10JSON00014c_","t":"qry","d":"EHS1qVNEkqH2a7SYRxDvQ2q0aUOp4rqEsmBamernO_5W","dt":"2023-03-10T20:52:53.906489+00:00","r":"mbx","rr":"","q":{"pre":"BPeRyrgFEUIDbtcKL-urikCsy9VaZ_RH1fPQhNwWOCj0","topics":{"/receipt":10},"i":"EAR1eNUllla9Y7l0ru0btqGrFoWuhLk8BkMWFUMEljUY","src":"BEXBtyNmAdUiEMsPYamGdMq4TEQfmitcFAyUYcY15Im2"}}'
