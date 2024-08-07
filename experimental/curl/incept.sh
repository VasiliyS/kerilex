#!/bin/bash

curl_wit(){
curl -X POST \
-H "Content-Type: application/cesr+json" \
-H "Cesr-Attachment: $1" \
-d $2 \
127.0.0.1:5631
}

curl_wit \
'-VAu-AABAACvSJCo4L2hVfTPk0YDRv2an1crda1UEDeVav8i0gyZNzW8U7b8POVIRCDX6oMOuQa2nVpIEBF3VR3US3vMuwUI-BABAAAdoBxC7zqYXpV8AhTiUQAOdZ2X2URvC0OHeCTq7KEs-j2q91jkKo_QcPl1KtY23ki_qLR3VwWeivuFtzEF3RsC' \
'{"v":"KERI10JSON00015d_","t":"icp","d":"EE_JGQw7kEYNBI-qY8QLXZimP9W5M-3lguOduY1w-v7y","i":"EE_JGQw7kEYNBI-qY8QLXZimP9W5M-3lguOduY1w-v7y","s":"0","kt":["1"],"k":["DOWR-nR0bSA8dbsvyc8EsnqEwyMdCuwks18ee0vTfqGn"],"nt":["1"],"n":["EKDeFrocsBkkl_a02izsnH98zzn7HN21oliTYqYbs9jt"],"bt":"1","b":["BB8Q8ohl4foA5UDd2RF3d_yjhxEFMzmkFT3qZnSXaK5u"],"c":[],"a":[]}'