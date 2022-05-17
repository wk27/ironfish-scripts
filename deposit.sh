#!/bin/bash
#
# /etc/crontab:
# @reboot root bash /root/deposit.sh >> /var/log/ironfish_deposit.log
#
# background start:
# nohup bash /root/deposit.sh >> /var/log/ironfish_deposit.log &
#
filename="$(basename $0)"

if [ ${filename} != "deposit.sh" ]; then
	echo -e '\033[0;31m'ERROR: This script must be named deposit.sh, your name is ${filename}'\033[0m'
	exit 1
fi

if [[ `pgrep -f ${filename}` != "$$" ]]; then
        echo "Another instance of shell already exist! Exiting"
	if [ -s "/var/run/${filename}.pid" ]; then echo "You can try to kill $(cat /var/run/${filename}.pid) process"; fi
        exit 1
fi

echo $$ > /var/run/${filename}.pid

dpkg -s bc > /dev/null 2>&1; if [ "$(echo $?)" != "0" ]; then apt-get -y install bc; fi

while true; do
BALANCE=$(/usr/bin/yarn --cwd ${HOME}/ironfish/ironfish-cli/ ironfish accounts:balance $IRONFISH_WALLET | egrep "Amount available to spend" | awk '{ print $6 }' | sed 's/\,//')
echo -e $(date): '\033[1;32m'"Available balance is ${BALANCE}"'\033[0m'
if (( $(echo "${BALANCE} >= 0.10000001" | bc -l) )); then
	REPEAT=$(echo ${BALANCE}/0.10000001 | bc -l | cut -d '.' -f1)
	if [ ! -z "${REPEAT}" ]; then
		for i in `seq ${REPEAT}`; do
			echo -e '\033[1;32m'"Transaction:"'\033[0m'
			/usr/bin/yarn --cwd ${HOME}/ironfish/ironfish-cli/ start deposit --confirm | tee /var/log/deposit-last.log
			echo -e '\033[0;31m'"-------------------------------------------------------------"'\033[0m'
			if [ ! -z "$(egrep "Insufficient funds" /var/log/deposit-last.log)" ]; then
				break
			fi
			sleep 5
		done
	fi
else
	sleep 5
fi
done
