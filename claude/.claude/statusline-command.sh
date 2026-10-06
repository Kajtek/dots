#!/bin/bash
# Claude Code status line: shows model name, reasoning effort, git branch,
# session token usage against the context window limit, and subscription
# rate-limit usage with reset times,
# e.g. "Fable high | feat/login* | 42.2k / 200k tokens (21%) | 5h 23% ↻14:30 | 7d 41% ↻Fri 09 Oct 09:00".
# Segments whose data is absent (no effort support, no Pro/Max rate limits,
# or before the session's first API response) are simply left out.

input=$(cat)

model=$(echo "$input" | jq -r '.model.display_name // "Claude"')
effort=$(echo "$input" | jq -r '.effort.level // empty')
[ -n "$effort" ] && model="$model $effort"

# Rate-limit windows: the rolling 5-hour session limit and the weekly limit.
# The 5h reset shows only the time when it falls today; the weekly one
# always carries the day and date.
limit_seg() {
  local label=$1 window=$2 pct resets when
  pct=$(echo "$input" | jq -r ".rate_limits.$window.used_percentage // empty")
  [ -z "$pct" ] && return
  resets=$(echo "$input" | jq -r ".rate_limits.$window.resets_at // empty")
  printf " | %s %s%%" "$label" "$(awk -v p="$pct" 'BEGIN { printf "%.0f", p }')"
  if [ -n "$resets" ]; then
    if [ "$window" = five_hour ] && [ "$(date -d "@$resets" +%F)" = "$(date +%F)" ]; then
      when=$(date -d "@$resets" +%H:%M)
    else
      when=$(date -d "@$resets" '+%a %d %b %H:%M')
    fi
    printf " ↻%s" "$when"
  fi
}
limits_seg="$(limit_seg 5h five_hour)$(limit_seg 7d seven_day)"

# Git branch of the workspace dir, with "*" when the tree is dirty.
# Shown in red on main/master as a "you are about to work on main" warning.
cwd=$(echo "$input" | jq -r '.workspace.current_dir // empty')
branch_seg=""
if [ -n "$cwd" ] && git -C "$cwd" rev-parse --is-inside-work-tree > /dev/null 2>&1; then
  branch=$(git -C "$cwd" branch --show-current 2>/dev/null)
  [ -z "$branch" ] && branch=$(git -C "$cwd" rev-parse --short HEAD 2>/dev/null)
  if [ -n "$branch" ]; then
    dirty=""
    git -C "$cwd" diff --quiet HEAD -- 2>/dev/null || dirty="*"
    case "$branch" in
      main|master) branch_seg=$(printf "\033[31m%s%s\033[0m\033[2m | " "$branch" "$dirty") ;;
      *)           branch_seg="$branch$dirty | " ;;
    esac
  fi
fi

# total_input_tokens is what actually counts against the context window
# (it already includes cache reads/writes), so it stays consistent with
# used_percentage / context_window_size.
used_tokens=$(echo "$input" | jq -r '.context_window.total_input_tokens // 0')
limit_tokens=$(echo "$input" | jq -r '.context_window.context_window_size // empty')
used_pct=$(echo "$input" | jq -r '.context_window.used_percentage // empty')

# Compact k-formatting, e.g. 42234 -> "42.2k", 200000 -> "200k", 500 -> "500".
format_k() {
  awk -v n="$1" 'BEGIN {
    if (n >= 1000) {
      v = n / 1000
      if (v == int(v)) printf "%dk", v
      else printf "%.1fk", v
    } else {
      printf "%d", n
    }
  }'
}

used_fmt=$(format_k "$used_tokens")

if [ -n "$limit_tokens" ] && [ "$limit_tokens" != "0" ]; then
  limit_fmt=$(format_k "$limit_tokens")

  if [ -n "$used_pct" ]; then
    pct_fmt=$(awk -v p="$used_pct" 'BEGIN { printf "%.0f", p }')
  else
    pct_fmt=$(awk -v u="$used_tokens" -v l="$limit_tokens" 'BEGIN { printf "%.0f", (u / l) * 100 }')
  fi

  printf "\033[2m%s | %s%s / %s tokens (%s%%)%s\033[0m" "$model" "$branch_seg" "$used_fmt" "$limit_fmt" "$pct_fmt" "$limits_seg"
else
  printf "\033[2m%s | %s%s tokens%s\033[0m" "$model" "$branch_seg" "$used_fmt" "$limits_seg"
fi
