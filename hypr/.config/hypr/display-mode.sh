#!/usr/bin/env bash
# Display mode menu, run by Super+P (see hyprland.lua), like Windows+P: pick PC screen only,
# Duplicate, Extend or Second screen only from a hyprlauncher list with the current mode marked,
# then a notification names the mode just applied.
#
# kanshi owns which outputs are on (profiles laptop / extend / second in kanshi/config): once
# kanshi has disabled an output, a Hyprland monitor rule cannot turn it back on, so the modes
# are kanshi profiles. Duplicate is extend plus a Hyprland mirror rule, because kanshi has no
# mirroring. Each switch starts with `hyprctl reload`, which drops a previous mirror rule and
# restores the per-PPI scales from hyprland.lua; kanshi keeps outputs on or off across it.
set -euo pipefail

INTERNAL="eDP-1"

notify() {
    notify-send -a "Display mode" -h string:x-canonical-private-synchronous:display-mode "$1"
}

fail() {
    notify "Display mode failed: $1"
    exit 1
}

# A second Super+P closes an open menu, including one stranded on an output that went dark.
if pkill -xf "hyprlauncher -m"; then
    exit 0
fi

# `monitors all` also lists disabled outputs, which is how a hidden screen is found again.
monitors=$(hyprctl monitors all -j)
mapfile -t externals < <(jq -r --arg int "$INTERNAL" '.[] | select(.name != $int) | .name' <<<"$monitors")
if (( ${#externals[@]} == 0 )); then
    notify "No external monitor connected"
    exit 0
fi

current=$(jq -r --arg int "$INTERNAL" '
    if any(.[]; .name == $int and .disabled) then "second"
    elif any(.[]; .name != $int and .disabled) then "laptop"
    elif any(.[]; .mirrorOf != "none") then "duplicate"
    else "extend" end' <<<"$monitors")

modes=(laptop duplicate extend second)
declare -A label=(
    [laptop]="PC screen only"
    [duplicate]="Duplicate"
    [extend]="Extend"
    [second]="Second screen only"
)

menu=""
for m in "${modes[@]}"; do
    line=${label[$m]}
    [[ "$m" == "$current" ]] && line+="  (current)"
    menu+="$line"$'\n'
done

# Escape closes the menu without a choice; leave the screens as they are.
choice=$(printf '%s' "$menu" | hyprlauncher -m) || exit 0
choice=${choice%  (current)}

mode=""
for m in "${modes[@]}"; do
    [[ "${label[$m]}" == "$choice" ]] && mode=$m
done
[[ -n "$mode" ]] || exit 0

err=$(hyprctl reload) || fail "$err"
if [[ "$mode" == "duplicate" ]]; then
    err=$(kanshictl switch extend 2>&1) || fail "$err"
    for out in "${externals[@]}"; do
        err=$(hyprctl eval "hl.monitor({ output = \"$out\", mode = \"preferred\", position = \"auto\", scale = \"auto\", mirror = \"$INTERNAL\" })") \
            || fail "$err"
    done
else
    err=$(kanshictl switch "$mode" 2>&1) || fail "$err"
fi
notify "${label[$mode]}"
