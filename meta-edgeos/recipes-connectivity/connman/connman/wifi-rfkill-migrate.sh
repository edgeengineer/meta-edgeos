#!/bin/sh
# One-time migration: read ConnMan WiFi policy and set rfkill state
# After this, systemd-rfkill owns persistence

set -e

# Exit if no WiFi hardware
if [ ! -e /sys/class/net/wlan0 ]; then
  exit 0
fi

# Read WiFi Enable from ConnMan settings (section-aware)
wifi_enabled=true
if [ -f /var/lib/connman/settings ]; then
  # Use awk to parse only the [WiFi] section
  wifi_enable=$(awk '
    /^\[WiFi\]/ { in_wifi=1; next }
    /^\[/ { in_wifi=0 }
    in_wifi && /^Enable=/ { print $0; exit }
  ' /var/lib/connman/settings | cut -d= -f2)

  if [ "$wifi_enable" = "false" ]; then
    wifi_enabled=false
  fi
fi

# Set rfkill state once - systemd-rfkill will persist it from now on
if [ "$wifi_enabled" = "false" ]; then
  rfkill block wifi
else
  rfkill unblock wifi
fi
