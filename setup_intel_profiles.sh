#!/bin/bash

# Define variables
URL="https://downloadmirror.intel.com/820388/814712_MTL_TuneD_Static_Profile_RN_Rev1p2.zip"
TMP_DIR=$(mktemp -d)              # Create a unique temporary directory
PROFILES_DIR="/etc/tuned/profiles" # Directory to move specific folders
PPD_CONF="/etc/tuned/ppd.conf"     # Path to the PPD configuration file
ZIP_BASENAME="814712_MTL_TuneD_Static_Profile_RN_Rev1p2.zip"
NESTED_ZIP_BASENAME="pkg.OPT.EPPprofile-1.05.240206.1-x86_64.zip"
EXTRACTED_DIR_BASENAME="pkg.OPT.EPPprofile-1.05.240206.1-x86_64"

# --- Functions ---
error_exit() {
  echo "ERROR: $1" >&2
  # Clean up temporary directory before exiting on error
  if [[ -d "$TMP_DIR" ]]; then
    echo "Cleaning up temporary files..."
    rm -rf "$TMP_DIR"
  fi
  exit 1
}

# --- Pre-checks ---
echo "Checking existing configuration..."
FULL_CONFIG=false
PARTIAL_INSTALL=false

if [[ -d "$PROFILES_DIR/intel-best_power_efficiency_mode" && -d "$PROFILES_DIR/intel-best_performance_mode" && -d "$PROFILES_DIR/intel-power_save_battery" ]]; then
  # Check if the ppd.conf is correctly configured (only if all dirs exist)
  if [[ -f "$PPD_CONF" ]] && \
     grep -qFx "power-saver=intel-best_power_efficiency_mode" "$PPD_CONF" && \
     grep -qFx "performance=intel-best_performance_mode" "$PPD_CONF" && \
     grep -qE "^balanced=intel-power_save_battery$" "$PPD_CONF"; then
     # Optional: Add checks for includes in tuned.conf files here if desired for full rigor
     FULL_CONFIG=true
  else
     echo "WARN: All Intel profile directories exist, but ppd.conf configuration seems incomplete or different."
     PARTIAL_INSTALL=true
  fi
elif [[ -d "$PROFILES_DIR/intel-best_power_efficiency_mode" || -d "$PROFILES_DIR/intel-best_performance_mode" || -d "$PROFILES_DIR/intel-power_save_battery" ]]; then
   echo "WARN: Some Intel profile directories exist but not all."
   PARTIAL_INSTALL=true
fi

# --- Handle Pre-check Results ---
if $FULL_CONFIG; then
    echo "Intel profiles appear to be already installed and fully configured."
    # Add a final check even if exiting early, just to be sure
    echo "Verifying active profile..."
    active_output=$(sudo tuned-adm active)
    active_profile=$(echo "$active_output" | awk -F': ' '{print $2}')
    if [[ "$active_profile" == "intel-best_performance_mode" || \
          "$active_profile" == "intel-best_power_efficiency_mode" || \
          "$active_profile" == "intel-power_save_battery" ]]; then
        echo "Current active profile ($active_profile) is one of the configured Intel profiles. Exiting."
    else
        echo "Current active profile ($active_profile) is NOT one of the expected Intel profiles. Consider activating one manually or checking PPD status."
    fi
    exit 0
fi

# *** ADDED CLEANUP STEP FOR PARTIAL INSTALL ***
if $PARTIAL_INSTALL; then
   echo "Attempting cleanup of existing partial/conflicting installation..."
   # Stop services that might be using the profiles before removing them
   echo "Stopping tuned services before cleanup..."
   sudo systemctl stop tuned.service tuned-ppd.service || echo "WARN: Could not stop tuned services, cleanup might fail if files are in use."
   sleep 2 # Give services a moment to stop

   sudo rm -rf "$PROFILES_DIR/intel-best_power_efficiency_mode" \
               "$PROFILES_DIR/intel-best_performance_mode" \
               "$PROFILES_DIR/intel-power_save_battery" || error_exit "Failed to remove existing profile directories. Please remove them manually (sudo rm -rf /etc/tuned/profiles/intel-*) and retry."
   echo "Existing conflicting profile directories removed."
   # Optionally, you could try to restore ppd.conf from backup here if it exists
   if [[ -f "$PPD_CONF.bak" ]]; then
       echo "Restoring $PPD_CONF from backup..."
       sudo cp "$PPD_CONF.bak" "$PPD_CONF" || echo "WARN: Failed to restore $PPD_CONF from backup."
   fi
fi

# --- Setup ---
# Ensure the temporary directory was created
if [[ ! "$TMP_DIR" || ! -d "$TMP_DIR" ]]; then
  error_exit "Failed to create temporary directory"
fi
echo "Temporary directory created at $TMP_DIR"

# Download the file
echo "Downloading Intel EPP Profiles from $URL..."
wget -q -P "$TMP_DIR" "$URL" || error_exit "Failed to download $URL"
echo "Download complete."

# Unzip the main file
echo "Unzipping main file: $ZIP_BASENAME..."
unzip -q "$TMP_DIR/$ZIP_BASENAME" -d "$TMP_DIR" || error_exit "Failed to unzip $ZIP_BASENAME"
echo "Main unzip complete."

# Unzip the nested zip file
echo "Unzipping nested TuneD Profiles zip file: $NESTED_ZIP_BASENAME..."
unzip -q "$TMP_DIR/$NESTED_ZIP_BASENAME" -d "$TMP_DIR" || error_exit "Failed to unzip $NESTED_ZIP_BASENAME"
echo "Nested unzip complete."

# Define source paths more clearly
SOURCE_EFFICIENCY_PROFILE="$TMP_DIR/$EXTRACTED_DIR_BASENAME/profiles/intel-best_power_efficiency_mode"
SOURCE_PERFORMANCE_PROFILE="$TMP_DIR/$EXTRACTED_DIR_BASENAME/profiles/intel-best_performance_mode"

# Check if source profiles exist after extraction
if [[ ! -d "$SOURCE_EFFICIENCY_PROFILE" || ! -d "$SOURCE_PERFORMANCE_PROFILE" ]]; then
    error_exit "Extracted profile directories not found in $TMP_DIR/$EXTRACTED_DIR_BASENAME/profiles/"
fi

# --- Move/Copy Profiles ---
echo "Moving profiles to $PROFILES_DIR..."
sudo mv "$SOURCE_EFFICIENCY_PROFILE" "$PROFILES_DIR/" || error_exit "Failed to move intel-best_power_efficiency_mode"
sudo mv "$SOURCE_PERFORMANCE_PROFILE" "$PROFILES_DIR/" || error_exit "Failed to move intel-best_performance_mode"
echo "Profiles moved."

echo "Creating intel-power_save_battery profile by copying intel-best_power_efficiency_mode..."
sudo cp -r "$PROFILES_DIR/intel-best_power_efficiency_mode" "$PROFILES_DIR/intel-power_save_battery" || error_exit "Failed to copy profile for intel-power_save_battery"
echo "intel-power_save_battery profile created."

# --- Configuration Backup & Adjustments ---
# Back up the existing ppd.conf file (only if it wasn't restored)
if ! $PARTIAL_INSTALL || ! [[ -f "$PPD_CONF.bak" ]]; then
    if [[ -f "$PPD_CONF" ]]; then
        echo "Backing up $PPD_CONF to $PPD_CONF.bak..."
        sudo cp "$PPD_CONF" "$PPD_CONF.bak" || error_exit "Failed to backup $PPD_CONF"
    else
        echo "WARN: $PPD_CONF not found. Skipping backup."
    fi
fi

echo "Configuring tuned.conf files..."
# Add include=balanced to intel-best_performance_mode/tuned.conf
sudo sed -i '/^\[main\]/a include=balanced' "$PROFILES_DIR/intel-best_performance_mode/tuned.conf" || error_exit "Failed to add include=balanced to performance profile"
# Add include=balanced to intel-best_power_efficiency_mode/tuned.conf
sudo sed -i '/^\[main\]/a include=balanced' "$PROFILES_DIR/intel-best_power_efficiency_mode/tuned.conf" || error_exit "Failed to add include=balanced to efficiency profile"
# Add include=balanced-battery to intel-power_save_battery/tuned.conf
sudo sed -i '/^\[main\]/a include=balanced-battery' "$PROFILES_DIR/intel-power_save_battery/tuned.conf" || error_exit "Failed to add include=balanced-battery to power_save_battery profile"
echo "tuned.conf files configured."

# Edit the ppd.conf file to set the profiles
if [[ -f "$PPD_CONF" ]]; then
    echo "Editing $PPD_CONF..."
    # Use precise matching to avoid unintended replacements
    sudo sed -i 's/^\(power-saver=\).*$/\1intel-best_power_efficiency_mode/' "$PPD_CONF" || error_exit "Failed to set power-saver in $PPD_CONF"
    sudo sed -i 's/^\(performance=\).*$/\1intel-best_performance_mode/' "$PPD_CONF" || error_exit "Failed to set performance in $PPD_CONF"
    # Set balanced in the [battery] section
    sudo sed -i '/^\[battery\]/,/^$/s/^\(balanced=\).*$/\1intel-power_save_battery/' "$PPD_CONF" || error_exit "Failed to set balanced under [battery] in $PPD_CONF"
    echo "$PPD_CONF edited."
else
     error_exit "$PPD_CONF not found. Cannot apply PPD configuration."
fi


# Restart services to apply changes
echo "Restarting services..."
sudo systemctl daemon-reload # Good practice after changing service-related files/configs potentially
sudo systemctl restart tuned.service || error_exit "Failed to restart tuned.service"
sudo systemctl status tuned.service --no-pager # Show status immediately
sudo systemctl restart tuned-ppd.service || echo "WARN: Failed to restart tuned-ppd.service. Check 'systemctl status tuned-ppd.service' and 'journalctl -xeu tuned-ppd.service' for details." # Treat PPD failure as warning
sudo systemctl status tuned-ppd.service --no-pager # Show status immediately
echo "Services restarted (check status and for warnings)."
sleep 2 # Give services a moment to settle before verification

# --- *** NEW: Final Verification *** ---
echo "-------------------------------------"
echo "Verifying installation..."
verification_passed=true

# Check 1: Profiles listed by tuned-adm
list_output=$(sudo tuned-adm list)
perf_present=$(echo "$list_output" | grep -q "^- intel-best_performance_mode"; echo $?)
eff_present=$(echo "$list_output" | grep -q "^- intel-best_power_efficiency_mode"; echo $?)
batt_present=$(echo "$list_output" | grep -q "^- intel-power_save_battery"; echo $?)

# Check grep exit codes (0 means found)
if [[ "$perf_present" -eq 0 && "$eff_present" -eq 0 && "$batt_present" -eq 0 ]]; then
    echo "[OK] Verification: All three Intel profiles are listed by 'tuned-adm list'."
else
    echo "[WARN] Verification: Not all expected Intel profiles were found in 'tuned-adm list'."
    [[ "$perf_present" -ne 0 ]] && echo "  - intel-best_performance_mode MISSING"
    [[ "$eff_present" -ne 0 ]] && echo "  - intel-best_power_efficiency_mode MISSING"
    [[ "$batt_present" -ne 0 ]] && echo "  - intel-power_save_battery MISSING"
    verification_passed=false
fi

# Check 2: Active profile is one of the expected Intel profiles
active_output=$(sudo tuned-adm active)
active_profile=$(echo "$active_output" | awk -F': ' '{print $2}') # Extract profile name after ': '

if [[ "$active_profile" == "intel-best_performance_mode" || \
      "$active_profile" == "intel-best_power_efficiency_mode" || \
      "$active_profile" == "intel-power_save_battery" ]]; then
    echo "[OK] Verification: Current active profile ($active_profile) is one of the configured Intel profiles."
elif [[ "$active_profile" == intel-* ]]; then
     echo "[INFO] Verification: Current active profile ($active_profile) is an Intel profile, but not one directly configured by this script for PPD standard modes."
     # This might be okay, but could indicate something else is overriding PPD
else
    echo "[WARN] Verification: Current active profile ($active_profile) is NOT one of the expected Intel profiles."
    echo "  Check 'systemctl status tuned-ppd.service' and power settings."
    verification_passed=false
fi
echo "-------------------------------------"

# --- Cleanup ---
echo "Cleaning up temporary files..."
rm -rf "$TMP_DIR"
echo "Cleanup complete."

if $verification_passed; then
    echo "Done! Installation and verification completed successfully."
else
    echo "Done! Installation completed, but verification checks reported warnings. Please review the output above."
fi
