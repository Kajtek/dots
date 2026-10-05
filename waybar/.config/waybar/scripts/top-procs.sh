#!/usr/bin/env bash
# Waybar custom/procs (procs.jsonc): the five busiest processes as a top-like table,
# drawn as a desktop card behind the windows.
#
# top, not ps: ps reports %CPU averaged over each process's lifetime, so a long-idle
# browser would outrank a short burst. top's first batch sample has the same problem,
# so take two and keep only the second, which covers the last second.
# LC_ALL=C keeps the decimal point a dot under a Polish locale.
# %CPU is per core (top's default Irix mode), so one busy process can exceed 100.
set -euo pipefail

rows=$(LC_ALL=C top -b -n 2 -d 1 -o %CPU -w 512 | awk '
    /^ *PID/ { n++; next }
    n == 2 && NF && c < 5 {
        c++
        cmd = $12; for (i = 13; i <= NF; i++) cmd = cmd " " $i
        printf "%s\t%s\t%s\n", $9, $10, cmd
    }')

# Pango markup, one line per process, Hack keeps the columns aligned. The meter is ten
# cells of one core (10 % each); a process over 50 % turns orange, the battery-warning
# colour in style.css. Names are cut before escaping (@html) so markup is never split.
jq -cRn --arg rows "$rows" '
    def pad(n): (. + (" " * n))[0:n];
    def lpad(n): ((" " * n) + .)[-n:];
    ($rows | split("\n") | map(split("\t"))) as $procs
    | [ "<span color=\"#21D6C9\" weight=\"bold\">\uf0ae  TOP PROCESSES</span>",
        "<span alpha=\"50%\">" + ("NAME" | pad(28)) + ("CPU" | lpad(8)) + ("MEM" | lpad(8)) + "</span>" ]
      + ($procs | map(
          (.[0] | tonumber) as $cpu
          | ([($cpu / 10 | round), 10] | min) as $on
          | (if $cpu > 50 then "#FF6633" else "#21D6C9" end) as $tint
          | (.[2] | pad(16) | @html)
            + "  <span color=\"\($tint)\">" + ("━━━━━━━━━━"[0:$on]) + "</span>"
            + "<span alpha=\"20%\">" + ("━━━━━━━━━━"[$on:]) + "</span>"
            + " <span color=\"\($tint)\">" + (.[0] | lpad(6)) + "%</span>"
            + "  <span alpha=\"70%\">" + (.[1] | lpad(5)) + "%</span>"))
    | { text: join("\n"), tooltip: "" }'
