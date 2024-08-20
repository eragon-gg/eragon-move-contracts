#bin/bash

echo "------ Set public key"
node set-pk.js
echo "------ Set operator"
node set-operator.js
echo "------ Set reward types"
node set-types.js
echo "------ Set seasons"
node set-seasons.js
echo "------ Set rewards"
node set-rewards.js
#echo "------ Faucet"
#node faucet-ra.js