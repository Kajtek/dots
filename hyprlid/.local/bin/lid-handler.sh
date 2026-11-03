#!/usr/bin/env bash
# Lid handler, run by Hyprland's "switch:on/off:Lid Switch" binds (see hyprland.lua).
# logind is configured to ignore the lid, so this script owns the policy:
#   closed, on battery            -> suspend
#   closed, on AC, external screen -> turn the internal panel off, keep working
#   closed, on AC, no external     -> suspend
#   open, external screen          -> extend: panel back on next to the external screens
#   open, no external              -> kanshi's automatic layout (the panel alone)
# kanshi turns outputs on and off here, as for Super+P: a Hyprland monitor rule cannot re-enable
# an output that is off, and once kanshi has changed an output Hyprland skips a rule it thinks
# is already applied. kanshi's "second" and "extend" profiles also match with no external screen
# (and "second" would then leave no screen at all), so they are only used after checking for one.
# `kanshictl reload` picks the first matching profile again, the same one a plug-in would.
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

# Connected external screens, on or off. FALLBACK is Hyprland's stand-in output while no real
# one is on, not a screen.
external_monitors() {
    hyprctl monitors all -j \
        | jq --arg int "$INTERNAL" '[.[] | select(.name != $int and .name != "FALLBACK")] | length'
}

if [[ "$(lid_state)" == "closed" ]]; then
    if [[ "$(ac_online)" == "1" && "$(external_monitors)" -gt 0 ]]; then
        kanshictl switch second
    else
        systemctl suspend
    fi
elif [[ "$(external_monitors)" -gt 0 ]]; then
    kanshictl switch extend
else
    kanshictl reload
fi
