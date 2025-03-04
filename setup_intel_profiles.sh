#!/bin/bash

# Define variables
URL="https://downloadmirror.intel.com/820388/814712_MTL_TuneD_Static_Profile_RN_Rev1p2.zip"
TMP_DIR=$(mktemp -d)              # Create a unique temporary directory
PROFILES_DIR="/etc/tuned/profiles" # Directory to move specific folders
PPD_CONF="/etc/tuned/ppd.conf"    # Path to the PPD configuration file

# Check if the profiles already exist
if [[ -d "$PROFILES_DIR/intel-best_power_efficiency_mode" && -d "$PROFILES_DIR/intel-best_performance_mode" ]]; then
  # Check if the ppd.conf is already configured
  if grep -q "power-saver=intel-best_power_efficiency_mode" "$PPD_CONF" && \
     grep -q "performance=intel-best_performance_mode" "$PPD_CONF"; then
    echo "The Intel profiles are already installed and configured."
    exit 0
  fi
fi

# Ensure the temporary directory was created
if [[ ! "$TMP_DIR" || ! -d "$TMP_DIR" ]]; then
  echo "Failed to create temporary directory"
  exit 1
fi

# Download the file
echo "Downloading Intel EPP Profiles..."
wget -P "$TMP_DIR" "$URL"

# Unzip the main file
echo "Unzipping main file..."
unzip "$TMP_DIR/814712_MTL_TuneD_Static_Profile_RN_Rev1p2.zip" -d "$TMP_DIR"

# Unzip the nested zip file
echo "Unzipping nested TuneD Profiles zip file..."
unzip "$TMP_DIR/pkg.OPT.EPPprofile-1.05.240206.1-x86_64.zip" -d "$TMP_DIR"

# Move specific folders to the profiles directory
echo "Moving specific folders to the profiles directory..."
sudo mv "$TMP_DIR/pkg.OPT.EPPprofile-1.05.240206.1-x86_64/profiles/intel-best_power_efficiency_mode" "$PROFILES_DIR"
sudo mv "$TMP_DIR/pkg.OPT.EPPprofile-1.05.240206.1-x86_64/profiles/intel-best_performance_mode" "$PROFILES_DIR"
sudo mv "$TMP_DIR/pkg.OPT.EPPprofile-1.05.240206.1-x86_64/profiles/intel-best_power_efficiency_mode" "$PROFILES_DIR/intel-power_save_battery"

# Back up the existing ppd.conf file
echo "Backing up the existing ppd.conf file..."
sudo cp "$PPD_CONF" "$PPD_CONF.bak"

# Add include=balanced to the end of the [main] section in the intel-best_performance_mode/tuned.conf
echo "Including the Balanced config in intel-best_performance_mode/tuned.conf..."
sudo sed -i '/^\[main\]/a include=balanced' "$PROFILES_DIR/intel-best_performance_mode/tuned.conf"

# Add include=balanced to the end of the [main] section in the intel-best_power_efficiency_mode/tuned.
echo "Including the Balanced config in intel-best_power_efficiency_mode/tuned.conf..."
sudo sed -i '/^\[main\]/a include=balanced' "$PROFILES_DIR/intel-best_power_efficiency_mode/tuned.conf"                         
                                                                    
# Add include=balanced-battery to the end of the [main] section in the intel-power_save_battery/tuned.conf
echo "Including the Balanced-Battery config in intel-best_power_efficiency_mode/tuned.conf..."
sudo sed -i '/^\[main\]/a include=balanced-battery' "$PROFILES_DIR/intel-power_save_battery/tuned.conf"

# Edit the ppd.conf file to set the profiles
echo "Editing the ppd.conf file..."
sudo sed -i 's/^power-saver=.*$/power-saver=intel-best_power_efficiency_mode/' "$PPD_CONF"
sudo sed -i 's/^performance=.*$/performance=intel-best_performance_mode/' "$PPD_CONF"

# Set balanced in the [battery] section to iintel-power_save_battery
sudo sed -i '/^\[battery\]/,/^$/s/^balanced=.*$/balanced=intel-power_save_battery/' "$PPD_CONF"

# Restart services to apply changes
echo "Restarting services..."
sudo systemctl restart tuned-ppd.service
sudo systemctl restart tuned.service

# Clean up temporary directory
echo "Cleaning up temporary files..."
rm -rf "$TMP_DIR"

echo "Done!"