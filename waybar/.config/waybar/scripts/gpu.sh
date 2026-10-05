#!/usr/bin/env bash
# Waybar custom/gpu: NVIDIA utilization, styled like the built-in cpu/memory/disk readings.
# "states" had no effect on this custom module, so the warning is decided here: from WARNING
# percent the module gets the "warning" class (orange in style.css) and a plain icon instead of
# the teal one.
#
# Only the NVIDIA dGPU is read: the Intel iGPU exposes no utilization without intel_gpu_top
# running as root. The dGPU never runtime-suspends (it drives the dock outputs), so polling it is
# cheap. No nvidia-smi or no driver prints nothing, which hides the module.
set -euo pipefail

WARNING=80
ICON=$'\U000f08ae'

usage=$(nvidia-smi --query-gpu=utilization.gpu --format=csv,noheader,nounits 2>/dev/null | head -n 1) || exit 0
if (( usage >= WARNING )); then
    printf '{"text": "%s %s%%", "class": "warning"}\n' "$ICON" "$usage"
else
    printf '{"text": "<span color=\\"#21D6C9\\">%s</span> %s%%"}\n' "$ICON" "$usage"
fi
