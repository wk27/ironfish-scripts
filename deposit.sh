#!/bin/bash
# /etc/crontab:
# @reboot root bash /root/deposit.sh >> /var/log/ironfish_deposit.log
#
# background start:
# bash /root/deposit.sh >> /var/log/ironfish_deposit.log &
#
source ~/.bashrc
source ~/.bash_profile

filename="$(basename $0)"

if [ ${filename} != "deposit.sh" ]; then
	echo -e '\033[0;31m'ERROR: This script must be named deposit.sh, your name is ${filename}'\033[0m'
	exit 1
fi

if [[ `pgrep -f ${filename}` != "$$" ]]; then
	echo "Another instance of the script already exist! Exiting"
	if [ -s "/var/run/${filename}.pid" ]; then echo -e "You can try to \033[0;31m kill -9 $(cat /var/run/${filename}.pid) \033[0m for killing the current process and then run a new one"; fi
	exit 1
fi

echo $$ > /var/run/${filename}.pid

dpkg -s bc > /dev/null 2>&1; if [ "$(echo $?)" != "0" ]; then apt-get -y install bc > /dev/null 2>&1; echo "Note: bc package has been installed"; fi
dpkg -s parallel > /dev/null 2>&1; if [ "$(echo $?)" != "0" ]; then apt-get -y install parallel > /dev/null 2>&1; echo "Note: parallel package has been installed"; fi

echo -e "Your wallet name is $IRONFISH_WALLET \nYour node name is ${IRONFISH_NODENAME} \nCheck these variables before running ${filename}"

while true; do
INSUFFICIENT_COUNT=0
BALANCE="$(/usr/bin/yarn --cwd ${HOME}/ironfish/ironfish-cli/ ironfish accounts:balance ${IRONFISH_WALLET} | egrep "Amount available to spend" | awk '{ print $6 }' | sed 's/\,//')"
echo ${BALANCE} > /tmp/.shadow_balance
echo -e $(date): '\033[1;32m'"Available balance is ${BALANCE}"'\033[0m'
if (( $(echo "${BALANCE} >= 0.10000001" | bc -l) )); then
	REPEAT=$(echo ${BALANCE}/0.10000001 | bc -l | cut -d '.' -f1)
	if [ ! -z "${REPEAT}" ]; then
		for i in `seq ${REPEAT}`; do
			if [ "$(($i % 10))" == 0 ] && [ "$i" != "1" ]; then
				echo $(/usr/bin/yarn --cwd ${HOME}/ironfish/ironfish-cli/ ironfish accounts:balance ${IRONFISH_WALLET} | egrep "Amount available to spend" | awk '{ print $6 }' | sed 's/\,//') > /tmp/.shadow_balance 2>&1 &
			fi
			if (( $(echo $(cat /tmp/.shadow_balance) \>\= 0.10000001 | bc -l) )) && [ "$i" != "1" ]; then
				echo -e $(date): '\033[1;32m'Possible balance amount is about $(echo $(cat /tmp/.shadow_balance)-\(${i}-1\)*0.10000001 | bc | sed "/^\./ s/\./0\./")'\033[0m'
			fi
			echo -e '\033[1;32m'"Transaction:"'\033[0m'
			/usr/bin/yarn --cwd ${HOME}/ironfish/ironfish-cli/ start deposit --confirm 2>&1 | tee /tmp/deposit-last.log
			echo -e '\033[0;31m'"-------------------------------------------------------------"'\033[0m'
			if [ ! -z "$(egrep -i "Insufficient" /tmp/deposit-last.log)" ]; then
				((INSUFFICIENT_COUNT++))
					if [ "${INSUFFICIENT_COUNT}" == "5" ] && [ -z "$(ps aux | egrep "accounts:rescan" | egrep -v grep | grep ironfish)" ] && [ "${1}" == "rescan-allowed" ]; then
						echo -e '\033[0;31m'Too many Insufficient errors. Rescan will start now.'\033[0m'
						/usr/bin/yarn --cwd ${HOME}/ironfish/ironfish-cli/ ironfish accounts:rescan
						INSUFFICIENT_COUNT=0
					fi
				sleep 300
				break
			fi
			if [ ! -z "$(egrep -i "An error occurred while sending the transaction" /tmp/deposit-last.log)" ]; then
				# It means that network is down, script will sleep for 30 minutes until next try
				sleep 1800
				break
			fi
		done
	fi
else
	sleep 15
fi
done
