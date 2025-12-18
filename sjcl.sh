#!/bin/env bash

printf '\n%s%b\n' "Super Janky Coal V2 Beta Leaderboooard V2 Beta!" "\U26CF \U26CF"

for i in curl jq tr python3 paste awk sort ; do
   [ "$(which $i)" == "" ] && echo "You need '$i' installed to run this script." && exit 1
done

stakes="$(mktemp)"

printf '\n\e[1;37m%s\e[49G%s\e[60G%s\e[1;32m\n\n%s\e[m' "Address" "Picks" "Stake" "Fetching..."

curl https://api.mainnet-beta.solana.com -s -X POST -H "Content-Type: application/json" -d '
   {
     "jsonrpc": "2.0",
     "id": 1,
     "method": "getProgramAccounts",
     "params": [
       "EG67mGGTxMGuPxDLWeccczVecycmpj2SokzpWeBoGVTf",
       {
         "encoding": "base58",
         "commitment": "confirmed",
         "dataSlice": {
           "offset": 40,
           "length": 32
         },
         "filters": [
           {
             "memcmp": {
               "offset": 0,
               "bytes": "VtB5VXd"
             }
           }
         ]
       }
     ]
   }
 ' | jq '.result[]|.account.data[0]' | tr -d '"' > "${stakes}.addresses"

curl https://api.mainnet-beta.solana.com -s -X POST -H "Content-Type: application/json" -d '
   {
     "jsonrpc": "2.0",
     "id": 1,
     "method": "getProgramAccounts",
     "params": [
       "EG67mGGTxMGuPxDLWeccczVecycmpj2SokzpWeBoGVTf",
       {
         "encoding": "base64",
         "dataSlice": {
           "offset": 120,
           "length": 8
         },
         "filters": [
           {
             "memcmp": {
               "offset": 0,
               "bytes": "VtB5VXd"
             }
           }
         ]
       }
     ]
   }
 ' | jq '.result[]|.account.data[0]' | tr -d '"' > "${stakes}"

python3 -c "
import base64
import sys
for line in sys.stdin:
    line = line.strip()
    if line:
        value = int.from_bytes(base64.b64decode(line), 'little') * 1e-11
        print(f'{value:19.11f}')
" < "${stakes}" > "${stakes}.formatted"

printf '\e[1G\e[1A'
paste "${stakes}.addresses" "${stakes}.formatted" | \
awk '{sum[$1] += $2; count[$1]++} END {for (name in sum) printf "%-44s %8d %22.11f\n", name, count[name], sum[name]}' | \
sort -k 3,3rn -k 2,2rn

echo
rm ${stakes}*