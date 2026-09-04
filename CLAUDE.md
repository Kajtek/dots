# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repo is

Personal dotfiles for an Arch Linux + Wayland/Hyprland laptop, managed with GNU Stow. There is no build, test suite, or linter. Verification means applying a config and checking the running program picks it up.

## Layout: one Stow package per top-level directory

Every top-level directory except `ansible/` is a Stow package whose contents mirror `$HOME`. So `waybar/.config/waybar/style.css` is symlinked to `~/.config/waybar/style.css`. Adding a new tool means creating a new top-level directory with the same `$HOME`-relative path underneath. Never place config files directly at the repo root.

`.stowrc` sets `--target=$HOME` and `--no-folding`. No-folding matters: directories in `$HOME` stay real directories and only files become links, so programs can write next to a stowed file without that write landing in the repo.

## Commands

```bash
./bootstrap.sh            # full bring-up (packages, system files, stow, verify) via ansible/playbook.yml; README.md documents it
./bootstrap.sh --check --diff   # dry run of the same
./install.sh              # interactive: pick packages; on conflict choose skip / overwrite (repo wins) / adopt (home wins)
./install.sh --dry-run    # passes --simulate to stow
stow <pkg>                # link one package (e.g. stow waybar)
stow -D <pkg>             # unlink one package
stow -R <pkg>             # relink after adding/removing files inside a package
```

Reload after editing:

```bash
Hyprland --verify-config -c hypr/.config/hypr/hyprland.lua   # offline check; must end with "config ok"
hyprctl reload && hyprctl configerrors    # hyprland.lua; configerrors must print nothing
pkill -x waybar; waybar -c ~/.config/waybar/top.jsonc & waybar -c ~/.config/waybar/bottom.jsonc &
pkill -x hypridle; hyprctl dispatch 'hl.dsp.exec_cmd("hypridle")'
```

With a Lua config, `hyprctl dispatch` and `hyprctl eval` take Lua expressions (`hyprctl dispatch 'hl.dsp.focus({ workspace = 3 })'`); `hyprctl keyword` no longer works, use `hyprctl eval 'hl.config({...})'` or `hl.monitor({...})` instead.

Waybar's `style.css` is shared by both bars and reloads live; the `.jsonc` files need a restart. `hyprlock.conf` has no validator short of locking the screen.

## How the pieces connect

- `ansible/` is the bring-up playbook, not a Stow package (`install.sh` skips it). Package lists and the Ubuntu source-build pins live in `ansible/vars/<Distribution>.yml`; adding a daemon to `hyprland.lua` means adding its package there and its binary to the list in `ansible/roles/verify/tasks/main.yml`. Lint with `ansible-lint` from inside `ansible/` (production profile).

- `hypr/.config/hypr/` holds `hyprland.lua` plus its companions `hypridle.conf` and `hyprlock.conf` (those two stay in hyprlang; only Hyprland itself moved to Lua). The `hyprland.start` handler in `hyprland.lua` starts every daemon (two waybar instances, mako, hyprpaper, hypridle, hyprsunset, kanshi, batsignal, tray applets). If you add a daemon, register it there.
- Two waybar bars, `top.jsonc` and `bottom.jsonc`, share one `style.css` and one `power_menu.xml`. Each jsonc file defines only the modules it lists.
- `mako/.config/mako/config` copies the waybar pill look (translucent black, `#21D6C9` border, Hack font); change the colours in both places together. Reload with `makoctl reload`.
- Lid handling: logind is set to ignore the lid in `/etc/systemd/logind.conf`, so Hyprland's `switch:on/off:Lid Switch` binds call `hyprlid/.local/bin/lid-handler.sh`, which decides between suspend and turning the internal panel off. `kanshi/config` separately disables the panel whenever the dock's `DP-5` output is present. Both touch `eDP-1`, so monitor changes should be checked against both.
- `bashrc` evals starship; `starship/.config/starship.toml` is intentionally empty (defaults).
- `claude/` tracks Claude Code's user-level config: `~/.claude/CLAUDE.md`, `settings.json`, `commands/`, the status-line script, and `~/CLAUDE.md`. Claude Code rewrites `settings.json` through the link when a setting changes in the app, so check `git diff` before committing.

## Conventions

- `.gitattributes` routes `*.jpg`, `*.png`, `*.blend` through Git LFS. Wallpapers or images go through LFS, not plain git.
- Commit messages are short and descriptive of the config change (see `git log`).
