#!/bin/bash
# Claude Code status line: shows model name, git branch, and session token
# usage against the context window limit,
# e.g. "Fable | feat/login* | 42.2k / 200k tokens (21%)".

input=$(cat)

model=$(echo "$input" | jq -r '.model.display_name // "Claude"')

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

  printf "\033[2m%s | %s%s / %s tokens (%s%%)\033[0m" "$model" "$branch_seg" "$used_fmt" "$limit_fmt" "$pct_fmt"
else
  printf "\033[2m%s | %s%s tokens\033[0m" "$model" "$branch_seg" "$used_fmt"
fi
