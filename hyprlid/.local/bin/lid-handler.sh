#!/usr/bin/env bash
# Lid handler, run by Hyprland's "switch:on/off:Lid Switch" binds (see hyprland.lua).
# logind is configured to ignore the lid, so this script owns the policy:
#   closed, on battery            -> suspend
#   closed, on AC, external screen -> turn the internal panel off, keep working
#   closed, on AC, no external     -> suspend
#   open                           -> turn the internal panel back on
# kanshi already disables the panel while docked, so the "open" branch only matters undocked.
set -euo pipefail

INTERNAL="eDP-1"

lid_state() {
    awk '{print $2}' /proc/acpi/button/lid/*/state
}

ac_online() {
    for p in /sys/class/power_supply/AC*/online; do
        [[ -f "$p" ]] && cat "$p" && return
    done
    echo 0
}

external_monitors() {
    hyprctl monitors -j | jq --arg int "$INTERNAL" '[.[] | select(.name != $int)] | length'
}

if [[ "$(lid_state)" == "closed" ]]; then
    if [[ "$(ac_online)" == "1" && "$(external_monitors)" -gt 0 ]]; then
        hyprctl eval "hl.monitor({ output = \"$INTERNAL\", disabled = true })"
    else
        systemctl suspend
    fi
else
    hyprctl eval "hl.monitor({ output = \"$INTERNAL\", mode = \"preferred\", position = \"auto\", scale = 1.5 })"
fi
