#!/bin/bash

# ironfish_cmd="ironfish"                                                  # use for NPM
ironfish_cmd="/usr/bin/yarn --cwd ${HOME}/ironfish/ironfish-cli/ ironfish" # use for SRC

fee="0.00001337"
wallet="default"

id="$(${ironfish_cmd} config:get blockGraffiti | sed -n '3p' | sed -e "s/^.//;s/.$//")"

${ironfish_cmd} wallet:mint -f=${wallet} -a=100 -n=${id} -m=${id} -o=${fee} -v --confirm

echo -e $(date): '\033[1;32m' > Need to wait the network... Do not close the script.'\033[0m'
echo

sleep 1337

asset_id="$(${ironfish_cmd} wallet:balances | grep ${id} | awk '{ print $2 }')"

${ironfish_cmd} wallet:burn -a=90 -f=${wallet} -o=${fee} -i=${asset_id} --confirm

echo -e $(date): '\033[1;32m' > Need to wait the network... Do not close the script.'\033[0m'
echo

sleep 666

${ironfish_cmd} wallet:send -i=${asset_id} -a=1 -t=dfc2679369551e64e3950e06a88e68466e813c63b100283520045925adbe59ca -f=${wallet} -o=${fee} --memo=${id} --confirm

echo -e $(date): '\033[1;32m'_________________________________________'\033[0m'
echo
