#!/bin/bash

watch -n 5 -c \
'echo -e "\e[32m$(date "+%Y-%m-%d %H:%M:%S")\e[0m: "
 active_profile=$(tuned-adm active)
if [[ "$active_profile" == *"intel"* ]]
then echo -e "\e[34m$active_profile\e[0m"
else echo -e "\e[33m$active_profile\e[0m"
fi
charging_status=$(cat /sys/class/power_supply/BAT1/status)
if [ "$charging_status" = "Charging" ] 
then echo -e "Charging status: \e[32m$charging_status\e[0m" 
elif [ "$charging_status" = "Discharging" ]
then echo -e "Charging status: \e[31m$charging_status\e[0m"
else echo -e "Charging status: \e[34m$charging_status\e[0m"
fi'
