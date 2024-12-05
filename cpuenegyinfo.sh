#!/bin/bash

n=$(nproc)

for i in $(seq 0 $((n-1))); do
    echo "cpu$i energy_performance_preference: $(cat /sys/devices/system/cpu/cpu$i/cpufreq/energy_performance_preference)"
    echo "cpu$i energy_perf_bias: $(cat /sys/devices/system/cpu/cpu$i/power/energy_perf_bias)"
done
