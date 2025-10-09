# WiFi Configuration in EdgeOS

## Overview

EdgeOS includes WiFi support via ConnMan and wpa_supplicant. WiFi is disabled by default for power management and must be explicitly enabled by the user.

## Architecture

- **ConnMan**: Network manager that provides the WiFi API
- **wpa_supplicant**: Handles WiFi authentication and connection
- **wireless-regdb**: Provides regulatory domain database
- **Udev**: Automatically brings up WiFi interfaces when detected

## Regulatory Domain (Country Code)

### Why It's Required

The Broadcom WiFi driver (brcmfmac) on Raspberry Pi **keeps WiFi soft-blocked** until a valid regulatory domain (country code) is set. This is a regulatory compliance requirement to ensure the device only transmits on frequencies legal in the user's country.

The kernel parameter `ieee80211_regdom` sets the **global default**, but the WiFi PHY device won't actually adopt it until **userspace sends a regulatory hint**. Until then, the PHY stays in the "world domain" (country 99) and remains soft-blocked.

### Default Configuration

EdgeOS sets the regulatory domain via a **udev rule** that runs when the WiFi PHY device appears:

**Udev Rule**: `/etc/udev/rules.d/85-wifi-regdomain.rules`
```
ACTION=="add", SUBSYSTEM=="ieee80211", KERNEL=="phy[0-9]*", \
  IMPORT{program}="/bin/sh -c 'c=$(cat /etc/regdomain 2>/dev/null || echo US); printf \"COUNTRY=%%s\\n\" \"$c\"'", \
  RUN+="/usr/sbin/iw reg set $env{COUNTRY}"
```

**Note**:
- Uses `printf` instead of `echo` to output KEY=VALUE format that udev expects
- `%%s` escapes the `%` for udev (udev uses `%` for its own substitutions) so it passes literal `%s` to the shell
- You may see a harmless warning about "invalid substitution type" in logs - udev complains about shell syntax it doesn't understand, but still executes correctly

**Country Code File**: `/etc/regdomain`
```
US
```

**How it works:**
- Triggers when WiFi PHY device (phy0) appears during boot
- Reads country code from `/etc/regdomain` (defaults to US if file missing)
- Runs `iw reg set <COUNTRY>` to send regulatory hint to kernel
- ConnMan manages rfkill state (WiFi is disabled by default, enabled by the user)
- Simple and reliable - no systemd service complexity

**Fallback**: `/etc/modprobe.d/cfg80211.conf`
```
options cfg80211 ieee80211_regdom=US
```

This sets the global default, but is not sufficient by itself - the PHY-specific regulatory hint via `iw reg set` is required.

### Provisioning Integration

**The provisioning flow MUST set the correct country code** for the user's location. To do this:

1. **During WiFi setup**, prompt the user for their country code (or derive from timezone/location)
2. **Update the regulatory domain file**:

```bash
# Set the country code (e.g., GB, DE, JP, etc.)
echo GB > /etc/regdomain
```

3. **Apply immediately without reboot**:

```bash
# Set regulatory domain immediately
iw reg set GB

# Enable WiFi (ConnMan will unblock rfkill automatically)
connmanctl enable wifi
```

**Alternative: Trigger udev to re-apply**:
```bash
# Trigger udev to re-read /etc/regdomain and apply
udevadm trigger -s ieee80211

# Verify it was applied
iw reg get
```

**Why this is safe:**
- Writes to a data file (`/etc/regdomain`), not editing udev rule syntax
- Can't break the udev rule with a typo
- Udev rule reads this file on every boot and applies it automatically

**Note**: `iw reg set` does NOT persist across reboots - it only sets the regulatory domain at runtime in kernel memory. The udev rule re-reads `/etc/regdomain` and reapplies it on every boot when the WiFi PHY appears.

### Valid Country Codes

Country codes follow ISO 3166-1 alpha-2 standard:
- `US` - United States
- `GB` - United Kingdom
- `DE` - Germany
- `JP` - Japan
- `CN` - China
- `AU` - Australia
- etc.

See `/lib/firmware/regulatory.db` or wireless-regdb documentation for complete list.

## WiFi Power Management

### Default State and Persistence

WiFi is **disabled by default** on first boot for power savings. This is controlled by `/etc/connman/main.conf` which excludes WiFi from `PreferredTechnologies`.

**After first boot:**
- User enables WiFi → ConnMan saves `Enable=true` to `/var/lib/connman/settings`
- WiFi stays enabled across reboots (persisted state)
- User disables WiFi → ConnMan saves `Enable=false`
- WiFi stays disabled across reboots (persisted state)

ConnMan naturally persists the user's WiFi preference.

### User Control

Users manage WiFi via ConnMan commands:

```bash
# Enable WiFi (required before scanning/connecting)
connmanctl enable wifi

# Disable WiFi (power saving)
connmanctl disable wifi

# Scan for networks
connmanctl scan wifi

# List available networks
connmanctl services
```

## Technical Details

### Why `ip link set wlan0 up` is Required

wpa_supplicant only registers interfaces that are **UP** with D-Bus/ConnMan. A udev rule automatically brings up WiFi interfaces when detected:

**File**: `/etc/udev/rules.d/80-wireless.rules`
```
SUBSYSTEM=="net", ACTION=="add", KERNEL=="wlan*", RUN+="/sbin/ip link set %k up"
```

### How WiFi Initialization Works

#### Boot Sequence
1. **Module Load**: cfg80211 module loads with `ieee80211_regdom=US` parameter (sets global default)
2. **Driver Init**: brcmfmac driver initializes - WiFi PHY appears as phy0 in "world domain" (country 99), registers with rfkill (default: unblocked)
3. **Udev Event**: ieee80211 subsystem fires ADD event for phy0
4. **Udev Rule Triggers**: `85-wifi-regdomain.rules` matches the phy0 device
5. **Regulatory Hint**: Rule runs `/usr/sbin/iw reg set US` which sends nl80211 regulatory hint to kernel
6. **Domain Applied**: Kernel cfg80211 applies US regulatory domain to phy0
7. **wlan0 appears**: Interface appears, rfkill device registered
8. **systemd-rfkill restores state**: Reads `/var/lib/systemd/rfkill/platform-*:wlan` and restores saved rfkill block/unblock state
9. **Migration service** (first boot only): Reads ConnMan settings, sets initial rfkill state
10. **Udev brings up wlan0**: `80-wireless.rules` runs `ip link set wlan0 up` so wpa_supplicant can register it
11. **ConnMan Starts**: Reads hardware rfkill state, synchronizes with persisted settings
12. **WiFi Nudge** (if WiFi enabled): Toggles WiFi to ensure wpa_supplicant registers wlan0 with ConnMan
13. **WiFi Ready**: Enabled or disabled based on persisted state, fully operational

#### When User Enables/Disables WiFi
1. **User Command**: `connmanctl enable wifi` or `connmanctl disable wifi`
2. **ConnMan Action**: Automatically manages rfkill (unblock/block)
3. **systemd-rfkill saves state**: Monitors `/dev/rfkill` and persists block/unblock state to `/var/lib/systemd/rfkill/platform-*:wlan`
4. **ConnMan synchronizes**: Updates `Enable=true/false` in `/var/lib/connman/settings` to match rfkill state
5. **Next Boot**: systemd-rfkill restores rfkill state → ConnMan reads it → WiFi state persisted

### WiFi State Persistence

**systemd-rfkill**: Persists WiFi enable/disable state across reboots

EdgeOS uses the standard `systemd-rfkill` service to persist WiFi radio state:
- When user enables WiFi → ConnMan unblocks rfkill → systemd-rfkill saves state to `/var/lib/systemd/rfkill/platform-*:wlan`
- When user disables WiFi → ConnMan blocks rfkill → systemd-rfkill saves state
- On boot → systemd-rfkill restores the saved rfkill state before ConnMan starts
- ConnMan reads the hardware rfkill state and synchronizes its settings

**Migration Service**: `wifi-rfkill-migrate.service`

One-time service that runs on first boot to migrate existing ConnMan WiFi policy into rfkill state:
- Reads `[WiFi] Enable=true/false` from `/var/lib/connman/settings`
- Sets initial rfkill state accordingly
- Creates marker file `/var/lib/systemd/wifi-rfkill-migrated` to prevent re-running
- Runs before ConnMan to ensure correct initial state

**WiFi Registration Nudge**: `wifi-nudge.service`

Ensures wpa_supplicant properly registers wlan0 with ConnMan on boot when WiFi is enabled:
- Runs after ConnMan starts
- If WiFi is enabled, performs a disable/enable cycle to ensure wpa_supplicant registration
- Harmless if WiFi is disabled (skips the toggle)
- Fixes race where wpa_supplicant doesn't register wlan0 before ConnMan checks

### Key Insights

✅ **PHY-aware timing**: udev rule runs when PHY actually exists, not "early" before it appears

✅ **Standard persistence**: Uses systemd-rfkill (standard Linux component) instead of custom solution

✅ **Clean separation**: udev owns regulatory domain, systemd-rfkill owns radio state persistence, ConnMan owns network management

✅ **No USB gadget interference**: ConnMan starts immediately for USB gadget networking; WiFi services run in parallel

✅ **Robust state handling**: rfkill is the single source of truth; ConnMan synchronizes to match hardware state

### Previous Failed Approaches

❌ **Kernel parameter `rfkill.default_state=1`**: Doesn't work - brcmfmac driver ignores it

❌ **Relying solely on `ieee80211_regdom` modprobe parameter**: Sets global default but WiFi PHY won't adopt it without userspace regulatory hint

❌ **Running `iw reg set` too early**: PHY doesn't exist yet, hint goes nowhere

❌ **wpa_supplicant country= with ConnMan**: wpa_supplicant runs in `-u` mode (D-Bus), won't read config file until ConnMan tells it to manage an interface (but WiFi is blocked so it can't)

❌ **Complex systemd services**: Early services can interfere with USB gadget and other boot processes

## Edge Cases and Considerations

### Multiple WiFi PHYs (USB Dongles)

The udev rule runs **per-PHY** automatically. If you plug in a USB WiFi dongle, it will get its own phy1 device and the regulatory domain will be set for it as well. This is the correct behavior.

### Country Code Provisioning

The recommended approach for setting the country code during provisioning:

```bash
# Update the country code file
echo GB > /etc/regdomain

# Trigger udev to re-apply immediately
udevadm trigger -s ieee80211

# Verify it was applied
iw reg get
```

This avoids manual `iw reg set` commands and ensures the setting persists across reboots.

### systemd-rfkill State Files

EdgeOS uses systemd-rfkill to persist WiFi radio state across reboots. State files are stored in `/var/lib/systemd/rfkill/`:
- `platform-*:wlan` - WiFi rfkill state (0 = unblocked, 1 = blocked)
- `platform-*:bluetooth` - Bluetooth rfkill state

**Do not manually edit these files.** They are managed automatically by systemd-rfkill when ConnMan toggles the radio state.

### Alternative Network Managers

If you ever switch from ConnMan to standalone wpa_supplicant (with `wpa_supplicant@wlan0.service`), you'll need to:

1. Add `country=XX` to `/etc/wpa_supplicant/wpa_supplicant-wlan0.conf`
2. Disable ConnMan's WiFi management

With ConnMan's `-u` D-Bus mode, the wpa_supplicant config file is ignored.

### Broadcom Firmware Requirements (Raspberry Pi)

Broadcom WiFi (brcmfmac) requires matching firmware files:

- Main firmware: `/lib/firmware/brcm/brcmfmac43455-sdio.bin` (or similar for your chip)
- CLM blob: `/lib/firmware/brcm/brcmfmac43455-sdio.clm_blob` (contains per-country channel/power limits)

If the CLM blob is missing, WiFi may fail to initialize or have limited channel access. The `wireless-regdb` package provides the general regulatory database, but Broadcom needs its own CLM blob.

## Troubleshooting

### WiFi is soft-blocked (expected behavior)

WiFi is **soft-blocked by default** for power saving. This is normal! To enable WiFi:

```bash
connmanctl enable wifi
```

Check the regulatory domain:
```bash
iw reg get
```

Should show:
```
global
country US: DFS-FCC
```

If it shows `country 00` or `country 99`, the regulatory domain is not set. Check if the udev rule executed:

```bash
# Test the udev rule manually
udevadm test --action=add /sys/class/ieee80211/phy0

# Check boot logs for udev rule execution
journalctl -b | grep -E 'ieee80211|iw reg'
```

### WiFi scan returns "Not implemented"

ConnMan is not built with WiFi support. Check:
```bash
connmanctl technologies
```

Should list `/net/connman/technology/wifi` - if missing, `wifi` is not in DISTRO_FEATURES.

### wlan0 interface doesn't appear

Check if wireless firmware is loaded:
```bash
dmesg | grep brcmfmac
```

Should see firmware loading successfully.

### WiFi scanning works but can't connect

Check wpa_supplicant is running with D-Bus support:
```bash
ps aux | grep wpa_supplicant
```

Should see `-u` flag (D-Bus mode).

### Missing regulatory database or firmware

For Raspberry Pi Broadcom WiFi:

```bash
# Check regulatory database
ls -la /lib/firmware/regulatory.db

# Check Broadcom firmware and CLM blob
ls -la /lib/firmware/brcm/ | grep -E 'brcmfmac.*\.(bin|txt|clm_blob)'

# Check kernel messages for firmware loading
dmesg | grep -i firmware
```

Required packages: `wireless-regdb`, `linux-firmware-bcm43455` (or equivalent for your hardware).

## Build Configuration

WiFi support is controlled by these Yocto variables:

**In `conf/distro/edgeos.conf`**:
```bitbake
DISTRO_FEATURES:append = " wifi"
```

**In `recipes-connectivity/connman/connman_%.bbappend`**:
```bitbake
PACKAGECONFIG:append = " wifi"
```

## Recipe Files

- `meta-edgeos/recipes-connectivity/connman/connman_%.bbappend` - ConnMan WiFi configuration, udev rules, and regulatory domain setup
- `meta-edgeos/recipes-core/packagegroups/packagegroup-edgeos-wifi.bb` - WiFi package group

## References

- [ConnMan Documentation](https://git.kernel.org/pub/scm/network/connman/connman.git/about/)
- [wpa_supplicant D-Bus API](https://w1.fi/wpa_supplicant/devel/dbus.html)
- [Linux Wireless Regulatory Documentation](https://wireless.wiki.kernel.org/en/developers/regulatory)
- [systemd-rfkill](https://www.freedesktop.org/software/systemd/man/systemd-rfkill.service.html)
