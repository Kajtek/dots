# dots

[![CI](https://github.com/Kajtek/dots/actions/workflows/ci.yml/badge.svg)](https://github.com/Kajtek/dots/actions/workflows/ci.yml)

Configuration for an Arch Linux + Hyprland laptop: Hyprland (Lua config), two waybar bars,
mako, kitty, hypridle/hyprlock, kanshi, a lid handler, and Claude Code settings. Files are
Stow packages that mirror `$HOME`; a small Ansible playbook installs everything they need
and links them, so a blank machine reaches the same desktop with one command.

## Supported targets

| Target | How the Hyprland stack arrives | Notes |
|---|---|---|
| Arch Linux (rolling) | pacman, plus `brave-bin` from the AUR | The reference machine. Full parity. |
| Ubuntu 26.04 LTS | apt for the tooling and desktop; Hyprland 0.56.2, its libraries and every hypr* tool built from pinned upstream releases into `/usr/local` with GCC 16 | Server or minimal install without another display manager. Greeter is tuigreet instead of regreet. VS Code is Microsoft's build, so `vscode-oss/argv.json` is not read. |

Ubuntu 24.04 is not supported: its compiler, sdbus-c++ and waybar are too old for this
Hyprland version. Other distributions fail early with a clear message.

## From zero

You need a user with sudo and a network connection. On Ubuntu start from a server or minimal
install; the playbook enables greetd as the display manager and will refuse to fight gdm.

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/Kajtek/dots/master/bootstrap.sh)
```

That installs git and Ansible with the distro package manager, clones this repo to
`~/projects/dots` (override with `DOTS_DIR`), asks for your sudo password once, and runs
the playbook. Arch takes a few minutes; Ubuntu takes longer because Hyprland is compiled.
Reboot when it finishes and log in through greetd.

From an existing checkout the same script uses that checkout instead of cloning, and passes
extra arguments to `ansible-playbook`:

```bash
./bootstrap.sh                  # apply everything
./bootstrap.sh --check --diff   # dry run: show what would change
./bootstrap.sh --tags dotfiles  # only relink the Stow packages
```

Rerunning is safe and is how you apply changes: every step is idempotent and reports
`changed` only when it did something.

## What the playbook does

Roles run in this order; each one is also a tag.

| Tag | Role | What it does |
|---|---|---|
| `packages` | `packages` | Arch: full upgrade, repo packages, AUR packages via makepkg. Ubuntu: vendor repos (Brave, Signal, VS Code), apt packages, Font Awesome 7 and Nerd Font symbols into `~/.local/share/fonts`, wl-clip-persist via cargo. |
| `build` | `source_builds` | Ubuntu only. Builds the entries of `source_builds` in `ansible/vars/Ubuntu.yml` in order: libwayland and wayland-protocols, Lua 5.5, the hypr* libraries, Hyprland, then hyprpaper, hypridle, hyprlock, hyprsunset, hyprlauncher, hyprpolkitagent, xdg-desktop-portal-hyprland and batsignal. Every download is checked against a pinned SHA-256. Each finished entry leaves a stamp under `/usr/local/share/dots-build/`, so a rerun skips it and a version bump rebuilds only that entry. |
| `system` | `system` | Files outside `$HOME`: a logind drop-in that leaves the lid switch to Hyprland, `/etc/greetd/config.toml` (regreet on Arch, tuigreet on Ubuntu), enabling greetd, NetworkManager, bluetooth and power-profiles-daemon. Warns when no swap is active. |
| `dotfiles` | `dotfiles` | `git lfs pull`, then stows every top-level directory except `ansible/`. A distro default file in the way (a fresh `~/.bashrc`) is moved to `<file>.pre-dots`; anything else in the way is an error, never overwritten. |
| `claude` | `claude_code` | Installs Claude Code with its native installer into `~/.local/share/claude`. |
| `verify` | `verify` | Fails if any program `hyprland.lua` starts or binds is missing from PATH, if `Hyprland --verify-config` does not print `config ok`, or if a link in `$HOME` does not point into the repo. |

Package lists and pinned versions live in `ansible/vars/Archlinux.yml` and
`ansible/vars/Ubuntu.yml`. The tasks only know how to drive each package manager.

## Not automated

- **GPU driver.** Hardware-specific; install it before the first login. The reference
  machine runs the NVIDIA DKMS driver with `nvidia-drm.modeset=1` on the kernel line.
- **Hibernation.** batsignal calls `systemctl hibernate` at 5% battery. That needs a swap
  partition at least the size of RAM, and either `resume=` on the kernel line or the
  `systemd` initramfs hook (which finds the image on its own).
- **Docking station.** `kanshi/.config/kanshi/config` disables the laptop panel when `DP-5`
  is present. Another dock shows up under another name; read it from `hyprctl monitors`.
- **Wallpaper.** hyprpaper starts without a config, so the desktop shows Hyprland's plain
  default. Add `~/.config/hypr/hyprpaper.conf` to the `hypr` package if you want one.
- **Accounts.** Git identity, SSH keys, Claude Code login, browser profiles.

## Day to day

Each top-level directory is a Stow package whose contents mirror `$HOME`, so
`waybar/.config/waybar/style.css` is linked to `~/.config/waybar/style.css`. Add a tool by
adding a directory with the same layout; `stow <pkg>` links it, `stow -D <pkg>` unlinks it,
`./install.sh` does the same interactively with conflict handling. Reload commands for each
program are in `CLAUDE.md`.

Ubuntu keeps its Hyprland at the pinned version until you bump it: edit the entry in
`ansible/vars/Ubuntu.yml` (version, URL, SHA-256) and rerun with `--tags build`. Keep the
library pins consistent with what the new Hyprland release wants (its `CMakeLists.txt` lists
the minimums); the Arch PKGBUILDs are a good source for matching sets and their checksums.
Nothing from apt's own hypr* packages is installed on Ubuntu, on purpose: with `/usr/local`
first on the library path they would load the source-built libraries next to their own.

## Continuous integration

Every push runs `.github/workflows/ci.yml`:

- **lint**: `ansible-lint` on the production profile, a playbook syntax check, and
  `shellcheck` on the scripts.
- **secrets**: gitleaks over the whole history. GitHub's own secret scanning and push
  protection are enabled on the repository as well.
- **bootstrap (arch)** and **bootstrap (ubuntu)**: `bootstrap.sh` runs in a blank
  `archlinux:latest` and a blank `ubuntu:26.04` container as an unprivileged user with
  sudo, exactly as on a new machine, then runs a second time and must report zero changes.

Containers have no systemd, GPU or hardware, so the playbook skips enabling services
there; the Hyprland config check and every other step run for real.

## Troubleshooting

- **A stow conflict stops the run.** The message names the path. Move it away (or diff it
  against the repo version and commit what you want to keep), then rerun.
- **A source build fails on Ubuntu.** The failing task shows the compiler output. Fix the
  cause (usually a missing `-dev` package after an Ubuntu update, add it to
  `apt_build_packages`), then rerun with `--tags build`; finished components are skipped.
- **greetd shows nothing after reboot.** `journalctl -u greetd` first. On Arch the greeter is
  a Hyprland session running regreet, so a broken GPU driver breaks the login screen too;
  switch to a text console and check `Hyprland` starts by hand.
- **The verify role lists a missing program.** It is exactly what `hyprland.lua` references
  but could not find; the package that provides it is missing from the distro list.
