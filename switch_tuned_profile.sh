#!/bin/bash

on_ac_power=$(cat /sys/class/power_supply/ACAD/online)
battery_status=$(cat /sys/class/power_supply/BAT1/status)

if [ "$on_ac_power" -eq 1 ]; then
  tuned-adm profile intel-best_performance_mode
elif [ "$battery_status" = "Discharging" ]; then
  tuned-adm profile intel-best_power_efficiency_mode
fi
