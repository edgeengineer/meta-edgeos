#!/bin/sh
# Hybrid USB Gadget (NCM-only) for Raspberry Pi 5 (Yocto)
# Subcommands:
#   prepare  - create configfs gadget (no bind)
#   bind [UDC]   - bind to UDC (arg optional; auto-picks first if omitted)
#   unbind  - unbind from UDC (leave gadget tree intact)
#   destroy - unbind (if bound) and remove gadget tree
#
# Note: No IP address work here—let systemd-networkd handle usb0.

set -eu

G="/sys/kernel/config/usb_gadget/g1"
CONF="c.1"
FUNC_NCM="ncm.usb0"
LANG="0x409"   # English (US) USB LANGID

log() { echo "[usb-gadget] $*"; }

mount_configfs() {
  [ -d /sys/kernel/config/usb_gadget ] || mount -t configfs none /sys/kernel/config
}

udc_name() { ls /sys/class/udc 2>/dev/null | head -n1; }

is_bound() { [ -f "$G/UDC" ] && [ -n "$(cat "$G/UDC" 2>/dev/null)" ]; }

prepare() {
  modprobe libcomposite 2>/dev/null || true
  mount_configfs

  if [ -d "$G" ]; then
    log "gadget already prepared at $G"
    return 0
  fi

  mkdir -p "$G"

  # --- Device IDs (replace with your own VID/PID for production) ---
  echo 0x1d6b > "$G/idVendor"      # placeholder!
  echo 0x0104 > "$G/idProduct"     # composite ID; fine for NCM testing
  echo 0x0200 > "$G/bcdUSB"
  echo 0x0100 > "$G/bcdDevice"

  # --- Strings ---
  mkdir -p "$G/strings/$LANG"
  echo "0123456789" > "$G/strings/$LANG/serialnumber"
  echo "MyCompany"  > "$G/strings/$LANG/manufacturer"
  echo "Pi5 NCM"    > "$G/strings/$LANG/product"

  # --- One configuration ---
  mkdir -p "$G/configs/$CONF"
  echo 120 > "$G/configs/$CONF/MaxPower"
  mkdir -p "$G/configs/$CONF/strings/$LANG"
  echo "NCM-only" > "$G/configs/$CONF/strings/$LANG/configuration"

  # --- NCM function ---
  mkdir -p "$G/functions/$FUNC_NCM"
  # Locally administered MACs (02:…)
  echo "02:12:34:56:78:ca" > "$G/functions/$FUNC_NCM/dev_addr"
  echo "02:12:34:56:78:cb" > "$G/functions/$FUNC_NCM/host_addr"
  # Optional tuning:
  # echo 5 > "$G/functions/$FUNC_NCM/qmult"

  # --- Microsoft OS descriptors so Windows auto-binds UsbNcm ---
  mkdir -p "$G/os_desc"
  echo 1        > "$G/os_desc/use"
  echo 0xbc     > "$G/os_desc/b_vendor_code"  # any non-zero value
  echo MSFT100  > "$G/os_desc/qw_sign"
  mkdir -p "$G/functions/$FUNC_NCM/os_desc/interface.ncm"
  echo WINNCM   > "$G/functions/$FUNC_NCM/os_desc/interface.ncm/compatible_id"
  ln -s "$G/configs/$CONF" "$G/os_desc/$CONF"

  # --- Link function into the config (no bind here) ---
  ln -s "$G/functions/$FUNC_NCM" "$G/configs/$CONF/"

  log "gadget prepared (not bound)"
}

bind() {
  [ -d "$G" ] || { log "ERROR: gadget not prepared; run '$0 prepare' first"; exit 1; }
  local UDC="${1:-$(udc_name)}"
  [ -n "$UDC" ] || { log "ERROR: no UDC found in /sys/class/udc (is dwc2 loaded?)"; exit 1; }

  # If already bound to this UDC, nothing to do
  if is_bound && [ "$(cat "$G/UDC")" = "$UDC" ]; then
    log "already bound to $UDC"
    return 0
  fi

  # If bound to a different UDC (unlikely), unbind first
  is_bound && echo "" > "$G/UDC" || true

  echo "$UDC" > "$G/UDC"
  log "bound to $UDC"
}

unbind() {
  [ -d "$G" ] || { log "no gadget present"; return 0; }
  if is_bound; then
    echo "" > "$G/UDC" || true
    log "unbound"
  else
    log "already unbound"
  fi
}

destroy() {
  # Unbind if needed
  unbind || true

  [ -d "$G" ] || { log "nothing to destroy"; return 0; }

  # Remove os_desc symlink to config first
  rm -f "$G/os_desc/$CONF" 2>/dev/null || true

  # Remove config -> function symlinks
  find "$G/configs" -maxdepth 2 -type l -delete 2>/dev/null || true

  # Remove function (drop its os_desc child first)
  rmdir "$G/functions/$FUNC_NCM/os_desc/interface.ncm" 2>/dev/null || true
  rmdir "$G/functions/$FUNC_NCM/os_desc"               2>/dev/null || true
  rmdir "$G/functions/$FUNC_NCM"                       2>/dev/null || true

  # Remove config strings & dirs
  rmdir "$G/configs/$CONF/strings/$LANG" 2>/dev/null || true
  rmdir "$G/configs/$CONF/strings"       2>/dev/null || true
  rmdir "$G/configs/$CONF"               2>/dev/null || true
  rmdir "$G/configs"                      2>/dev/null || true

  # Remove strings dir
  rmdir "$G/strings/$LANG" 2>/dev/null || true
  rmdir "$G/strings"       2>/dev/null || true

  # Remove os_desc dir
  rmdir "$G/os_desc" 2>/dev/null || true

  # If a webusb dir ever exists, drop it too (no file deletes)
  rmdir "$G/webusb" 2>/dev/null || true

  # Finally remove the gadget root
  rmdir "$G" 2>/dev/null || true

  log "gadget destroyed"
}

case "${1:-}" in
  prepare) prepare ;;
  bind)    shift || true; bind "${1:-}" ;;
  unbind)  unbind ;;
  destroy) destroy ;;
  *) echo "Usage: $0 {prepare|bind [UDC]|unbind|destroy}"; exit 2 ;;
esac
