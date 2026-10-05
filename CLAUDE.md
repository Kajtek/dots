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
pkill -x waybar                                  # hyprland.lua respawns both bars; last output in ~/.cache/waybar-{top,bottom}.log
pkill -x hypridle; hyprctl dispatch 'hl.dsp.exec_cmd("hypridle")'
```

With a Lua config, `hyprctl dispatch` and `hyprctl eval` take Lua expressions (`hyprctl dispatch 'hl.dsp.focus({ workspace = 3 })'`); `hyprctl keyword` no longer works, use `hyprctl eval 'hl.config({...})'` or `hl.monitor({...})` instead.

Waybar's `style.css` is shared by both bars and reloads live; the `.jsonc` files need a restart. `hyprlock.conf` has no validator short of locking the screen.

## How the pieces connect

- `ansible/` is the bring-up playbook, not a Stow package (`install.sh` skips it). Package lists and the Ubuntu source-build pins live in `ansible/vars/<Distribution>.yml`; adding a daemon to `hyprland.lua` means adding its package there and its binary to the list in `ansible/roles/verify/tasks/main.yml`. Lint with `ansible-lint` from inside `ansible/` (production profile).

- `hypr/.config/hypr/` holds `hyprland.lua` plus its companions `hypridle.conf`, `hyprlock.conf` and `hyprtoolkit.conf` (the theme for hyprlauncher and other hyprtoolkit apps); the companions stay in hyprlang, only Hyprland itself moved to Lua. The `hyprland.start` handler in `hyprland.lua` starts every daemon (three waybar instances: two bars and the process card; mako, hyprpaper, hypridle, hyprsunset, kanshi, batsignal, tray applets). If you add a daemon, register it there.
- Two waybar bars, `top.jsonc` and `bottom.jsonc`, share one `style.css` and one `power_menu.xml`. Each jsonc file defines only the modules it lists. A third instance, `procs.jsonc`, is not a bar but a desktop card on the `bottom` layer (behind windows) listing the top five processes from `scripts/top-procs.sh`; it shares the same `style.css` and respawn loop.
- `mako/.config/mako/config` copies the waybar pill look (translucent black, `#21D6C9` border, Hack font). Reload with `makoctl reload`.
- One accent across the desktop: teal `#21D6C9`, fading into cyan `#33ccff` on gradients, and `#FF6633` only for warnings and errors. It is repeated in waybar `style.css` and the jsonc formats, `top-procs.sh` and `gpu.sh`, mako, `hyprland.lua` (window borders), `hyprlock.conf`, `hyprtoolkit.conf`, `kitty.conf`, the two `gtk/.config/gtk-*/gtk.css` and the login screen's `ansible/roles/system/files/greetd-regreet.css`; change it everywhere together. Translucent layers need a blur rule in `hyprland.lua` matched on their layer namespace (`waybar`, `procs`, `notifications`, `hyprlauncher`).
- Lid and power key: logind is set to ignore the lid and to suspend on a short power-key press (`ansible/roles/system/files/logind-lid.conf`), so Hyprland's `switch:on/off:Lid Switch` binds call `hyprlid/.local/bin/lid-handler.sh`, which decides between suspend and turning the internal panel off. `kanshi/config` separately disables the panel whenever the dock's `DP-5` output is present. Both touch `eDP-1`, so monitor changes should be checked against both.
- `gtk/` holds the GTK 3/4 `settings.ini` (theme `adw-gtk3-dark` from `adw-gtk-theme`, dark, Hack 10) and a `gtk.css` each that sets the teal accent. On Wayland GTK reads the theme from gsettings instead, so the `hyprland.start` handler mirrors these values with `gsettings set`; change both together. Qt apps follow the same theme through `QT_QPA_PLATFORMTHEME=gtk3`. The cursor, `Breeze_Light`, is named in `hyprland.lua` (env and gsettings), both `settings.ini`, and the greeter's `greetd-hyprland.lua` and `greetd-regreet.toml`.
- `bashrc` evals starship; `starship/.config/starship.toml` is intentionally empty (defaults).
- `claude/` tracks Claude Code's user-level instructions: `~/.claude/CLAUDE.md`, `commands/`, the status-line script, and `~/CLAUDE.md`. `~/.claude/settings.json` is deliberately a local file, ignored in `.gitignore`: Claude Code writes local paths and other projects' details into it.

## Conventions

- `.gitattributes` routes `*.jpg`, `*.png`, `*.blend` through Git LFS. Wallpapers or images go through LFS, not plain git.
- Commit messages are short and descriptive of the config change (see `git log`).
