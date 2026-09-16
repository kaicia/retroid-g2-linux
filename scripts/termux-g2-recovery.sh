#!/data/data/com.termux/files/usr/bin/bash
# G2 slot-recovery helper for a Termux HOST phone driving the bricked G2 over
# USB-OTG. Reaches fastboot / fastbootd without root, the same channel the
# earlier hardware dumps were collected through (termux-adb, nohajc).
#
# What it can and cannot do:
#   * bootloader fastboot  (green START screen)  -> read-only only; ABL here
#                                                   has no set_active
#   * fastbootd            (userspace fastboot)  -> set_active WORKS here; if
#                                                   this is reachable the brick
#                                                   is fixed with no firehose
#   * EDL / 9008                                 -> NOT reachable this way; EDL
#                                                   needs a firehose + a
#                                                   different tool
#
# It never issues a write on its own. It reads state, shows it, and asks before
# the one command that changes anything.

set -u
say(){ printf '\n== %s\n' "$*"; }
ask(){ printf '%s [y/N] ' "$*"; read -r a; [ "$a" = y ] || [ "$a" = Y ]; }

# ---- pick the fastboot wrapper --------------------------------------------
if command -v termux-fastboot >/dev/null 2>&1; then
  if command -v fakeroot >/dev/null 2>&1; then
    FB(){ ANDROID_NO_USE_FWMARK_CLIENT=1 fakeroot termux-fastboot "$@"; }
  else
    FB(){ ANDROID_NO_USE_FWMARK_CLIENT=1 termux-fastboot "$@"; }
  fi
  echo "fastboot: termux-fastboot (no root, OTG)"
elif command -v fastboot >/dev/null 2>&1; then
  FB(){ fastboot "$@"; }
  echo "fastboot: android-tools fastboot (needs root for USB)"
else
  echo "ERROR: no fastboot. Install nohajc/termux-adb:"
  echo "  pkg install -y curl"
  echo "  curl -s https://raw.githubusercontent.com/nohajc/termux-adb/master/install.sh | bash"
  echo "  then reopen Termux."
  exit 1
fi

# ---- 1. see the device -----------------------------------------------------
say "1/4  Looking for the G2 over OTG (device must be on the fastboot screen)"
FB devices
echo
echo "If that listed a serial + 'fastboot', good. If empty:"
echo "  - reseat the USB-C cable, tap 'grant USB permission' on THIS phone,"
echo "  - make sure the G2 shows the green START / fastboot screen."
ask "Did a device show up?" || { echo "Stop here and fix the cable/permission."; exit 1; }

# ---- 2. which fastboot are we in? -----------------------------------------
say "2/4  Which fastboot is this?"
IS_USERSPACE="$(FB getvar is-userspace 2>&1 | tr -d '\r' | awk -F': ' '/is-userspace/{print $2; exit}')"
CUR="$(FB getvar current-slot 2>&1 | tr -d '\r' | awk -F': ' '/current-slot/{print $2; exit}')"
echo "  is-userspace = ${IS_USERSPACE:-?}    current-slot = ${CUR:-?}"
echo
echo "  is-userspace = no   -> bootloader fastboot (ABL). set_active is NOT here."
echo "  is-userspace = yes  -> fastbootd. set_active WORKS here."

# ---- 3. if in bootloader, try to reach fastbootd --------------------------
if [ "${IS_USERSPACE:-no}" != "yes" ]; then
  say "3/4  In bootloader fastboot. Trying to reach fastbootd..."
  echo "  Sending 'reboot fastboot'. The device reboots; it can take ~30s and"
  echo "  the command may print 'waiting for device' then give up - that is"
  echo "  normal, the device reappears after."
  ask "Send 'reboot fastboot' now?" || { echo "Skipped."; exit 0; }
  FB reboot fastboot || true
  echo
  echo "Waiting 40s for the recovery/fastbootd ramdisk to come up..."
  sleep 40
  IS_USERSPACE="$(FB getvar is-userspace 2>&1 | tr -d '\r' | awk -F': ' '/is-userspace/{print $2; exit}')"
  echo "  is-userspace now = ${IS_USERSPACE:-?}"
  if [ "${IS_USERSPACE:-no}" != "yes" ]; then
    echo
    echo "fastbootd did not come up. That means the recovery ramdisk on the"
    echo "active slot (a) is not booting either - the firehose/EDL route is"
    echo "still needed. Nothing was changed. Stopping."
    exit 0
  fi
fi

# ---- 4. in fastbootd: the fix ---------------------------------------------
say "4/4  In fastbootd. This is where the brick can be undone."
CUR="$(FB getvar current-slot 2>&1 | tr -d '\r' | awk -F': ' '/current-slot/{print $2; exit}')"
echo "  current-slot = ${CUR:-?}   (we want to switch this to b)"
echo
echo "  slot b state (should be bootable):"
FB getvar slot-successful:b 2>&1 | tr -d '\r' | grep -i slot-successful || true
FB getvar slot-unbootable:b 2>&1 | tr -d '\r' | grep -i slot-unbootable || true
echo
echo "  The next command WRITES: it sets the active slot back to b."
echo "  Slot b holds the working Android, so this is the fix, not a risk."
ask "Run 'fastboot set_active b'?" || { echo "Not run. Nothing changed."; exit 0; }
FB set_active b
echo
echo "Confirming:"
FB getvar current-slot 2>&1 | tr -d '\r' | grep -i current-slot || true
echo
echo "If current-slot is now b: run  termux-fastboot reboot  (or reboot the G2)."
echo "It should boot Android. If it lands back in fastboot instead of Android,"
echo "tell Claude - the UFS boot LUN may also need setting and that needs EDL."
