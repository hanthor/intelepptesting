#!/bin/bash

# Create necessary directories
mkdir -p ~/.local/bin
mkdir -p ~/.local/share/systemd/user

# Write the script content to ~/.local/bin/switch_tuned_profile.sh
cat << 'EOF' > ~/.local/bin/switch_tuned_profile.sh
#!/bin/bash

on_ac_power=$(cat /sys/class/power_supply/ACAD/online)
battery_status=$(cat /sys/class/power_supply/BAT1/status)

if [ "$on_ac_power" -eq 1 ]; then
  tuned-adm profile balanced
elif [ "$battery_status" = "Discharging" ]; then
  tuned-adm profile powersave
fi
EOF

# Write the service file content to ~/.local/share/systemd/user/switch-tuned-profile.service
cat << 'EOF' > ~/.local/share/systemd/user/switch-tuned-profile.service
[Unit]
Description=Switch tuned profile based on power source

[Service]
Type=oneshot
ExecStart=$HOME/.local/bin/switch_tuned_profile.sh
EOF

# Write the timer file content to ~/.local/share/systemd/user/switch-tuned-profile.timer
cat << 'EOF' > ~/.local/share/systemd/user/switch-tuned-profile.timer
[Unit]
Description=Run switch-tuned-profile.service every 3 minutes

[Timer]
OnBootSec=3min
OnUnitActiveSec=3min

[Install]
WantedBy=timers.target
EOF

# Make the script executable
chmod +x ~/.local/bin/switch_tuned_profile.sh

# Reload systemd user daemon
dbus-send --session --dest=org.freedesktop.systemd1 --type=method_call --print-reply \
    /org/freedesktop/systemd1 org.freedesktop.systemd1.Manager.Reload

# Enable and start the timer
systemctl --user enable switch-tuned-profile.timer
systemctl --user start switch-tuned-profile.timer

echo "Service and timer installed successfully."