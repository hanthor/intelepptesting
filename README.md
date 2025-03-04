# Script to Download and Setup Intel's TuneD EPP Powersave and Performance Profiles for the Meteor Lake, Lunar Lake, etc.

The newer Intel CPUs have some good power saving but some of this saving hasn't been realised on Linux yet. This download the TuneD profiles from intel.com and sets the Intel profiles as default balanced, performance and battery profiles using Tuned-ppd.

# Installation

- *setup_intel_profiles.sh* - Downloads and configure the Intel EPP profiles as default in `ppd.conf`

# Other Scripts

- *powerprof.sh* - watches the current charge state and tuned profile, so you can monitor the power profile switching
- *cpuenergyinfo.sh* - outputs the current EPP setting on all the cpu cores


# What these Intel EPP profiles do

## intel-best_power_efficiency_mode

sets `energy_performance_preference` to 178
sets `energy_perf_bias` to 8

## intel-best_performance_mode

sets `energy_performance_preference` to 64