#!/bin/bash

curl_wit(){
curl -X POST \
-H "Content-Type: application/cesr+json" \
-H "Cesr-Attachment: $1" \
-d $2 \
127.0.0.1:5631
}

curl_wit \
'-VAi-CABBB8Q8ohl4foA5UDd2RF3d_yjhxEFMzmkFT3qZnSXaK5u0BC76suoD4OnDXSDk3Q7_4pqG9wUOjmfOE91G7meVkrD9grs5L_O5YJi9WPlJ0cc61XoU8iY7qRguD9Vyubn-wkL' \
'{"v":"KERI10JSON0000fa_","t":"rpy","d":"EIxYPqp-PbOAq8uGA8OWK0BQGbF2LFEM7u6iwjXfCAQj","dt":"2023-04-06T16:00:07.609425+00:00","r":"/loc/scheme","a":{"eid":"BB8Q8ohl4foA5UDd2RF3d_yjhxEFMzmkFT3qZnSXaK5u","scheme":"http","url":"http://127.0.0.1:5555/"}}'