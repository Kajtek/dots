# dots

[![CI](https://github.com/Kajtek/dots/actions/workflows/ci.yml/badge.svg)](https://github.com/Kajtek/dots/actions/workflows/ci.yml)

A Hyprland laptop setup for Arch Linux and Ubuntu: Hyprland with a Lua config, two waybar
bars, mako, kitty, hypridle and hyprlock, kanshi, a lid handler, and Claude Code settings.
The configs are GNU Stow packages that mirror `$HOME`. An Ansible playbook installs
everything they need and links them, so a blank machine reaches the same desktop with one
command, and rerunning that command applies later changes.

## Contents

- [Supported targets](#supported-targets)
- [From zero](#from-zero)
- [What the playbook does](#what-the-playbook-does)
- [Repository layout](#repository-layout)
- [Day to day](#day-to-day)
- [Updating](#updating)
- [Not automated](#not-automated)
- [Security](#security)
- [Continuous integration](#continuous-integration)
- [Troubleshooting](#troubleshooting)
- [License](#license)

## Supported targets

| | Arch Linux | Ubuntu 26.04 LTS |
|---|---|---|
| Hyprland stack | `hyprland` and the hypr* tools from the official repos | Hyprland 0.56.2, its libraries and every hypr* tool built from pinned upstream releases into `/usr/local` with GCC 16 |
| Other packages | pacman; `brave-bin` from the AUR through `makepkg` | apt, plus the Brave, Signal and VS Code vendor repositories |
| Login screen | greetd with regreet, hosted by a minimal Hyprland session | greetd with tuigreet |
| VS Code | Code - OSS, which reads the tracked `argv.json` | Microsoft's build, which does not |
| Package list | `ansible/vars/Archlinux.yml` | `ansible/vars/Ubuntu.yml` |

Both distributions end up with the same Hyprland version and the same daemons, so the
configs behave the same on either. Ubuntu 24.04 is not supported: its compiler, sdbus-c++
and waybar are too old for this Hyprland release. Any other distribution is refused before
anything is changed.

## From zero

Requirements on both distributions: a user account with sudo (not root), a network
connection, and no other display manager. On Ubuntu start from a server or minimal install.

Either clone first and run the script from the checkout:

```bash
git clone https://github.com/Kajtek/dots.git ~/projects/dots
cd ~/projects/dots
./bootstrap.sh
```

or let the script clone for you:

```bash
curl -fsSLO https://raw.githubusercontent.com/Kajtek/dots/master/bootstrap.sh
less bootstrap.sh    # it is short; read it before running it
bash bootstrap.sh    # clones to ~/projects/dots, or $DOTS_DIR if set
```

`bootstrap.sh` installs git and Ansible with the distribution's package manager, then hands
over to `ansible/playbook.yml`. It asks for your sudo password twice: once for that package
install and once for the playbook, because the playbook can outlast sudo's credential
cache. Accounts with passwordless sudo are not asked at all. Arch finishes in a few minutes;
Ubuntu takes longer because Hyprland is compiled. Reboot when it is done and log in
through greetd.

Every further run is the same command. Arguments pass through to `ansible-playbook`:

```bash
./bootstrap.sh                  # apply everything
./bootstrap.sh --check --diff   # dry run: show what would change
./bootstrap.sh --tags dotfiles  # only relink the Stow packages
```

Every step is idempotent and reports `changed` only when it did something, so a second run
on an unchanged machine reports zero changes. That is also what CI checks.

## What the playbook does

Roles run in this order. Each is also a tag for `--tags`.

| Tag | What it does on Arch Linux | What it does on Ubuntu |
|---|---|---|
| `packages` | Full system upgrade, then the repo packages, then each AUR package: clone the PKGBUILD, install its dependencies from the repos, build with `makepkg` as the user, install the result. | Vendor repositories (deb822, signed by the vendors' own keys), the apt packages, Font Awesome 7 and the Nerd Font symbols into `~/.local/share/fonts`, and wl-clip-persist built with cargo from a pinned commit. |
| `build` | Nothing; the list is empty. | Each entry of `source_builds` in `ansible/vars/Ubuntu.yml` in order: libwayland and wayland-protocols, Lua 5.5, the hypr* libraries, Hyprland, then hyprpaper, hypridle, hyprlock, hyprsunset, hyprlauncher, hyprpolkitagent, xdg-desktop-portal-hyprland and batsignal. A finished entry leaves a stamp in `/usr/local/share/dots-build/`, so reruns skip it. |
| `system` | The files outside `$HOME` the configs assume: a logind drop-in that leaves the lid switch to Hyprland, `/etc/greetd/config.toml`, the Hyprland session that hosts regreet, and enabling greetd, NetworkManager, bluetooth and power-profiles-daemon. Warns when no swap is active. | The same, with tuigreet as the greeter. |
| `dotfiles` | `git lfs pull`, then every top-level directory except `ansible/` is stowed. A distribution default in the way (a fresh `~/.bashrc`) is moved to `<file>.pre-dots` once; anything else in the way is an error, never overwritten. | Same. |
| `claude` | Claude Code through its native installer into `~/.local/share/claude`, skipped when it is already installed. | Same. |
| `verify` | Fails if any program `hyprland.lua` starts or binds is missing from PATH, if `Hyprland --verify-config` does not print `config ok`, if hyprlock's PAM service is missing (a lock that could not be unlocked), or if a link in `$HOME` does not point into the repo. | Same. |

The tasks under `ansible/roles/` only know how to drive each package manager; what gets
installed is entirely in `ansible/vars/`. Adding a daemon to `hyprland.lua` means adding its
package to both vars files and its binary to the list in the verify role.

## Repository layout

Every top-level directory except `ansible/` is a Stow package whose contents mirror
`$HOME`, so `waybar/.config/waybar/style.css` is linked to `~/.config/waybar/style.css`.
`.stowrc` sets the target to `$HOME` and `--no-folding`, so directories in `$HOME` stay real
directories and only files become links; programs can write next to a linked file without
that write landing in the repo.

| Package | What it holds |
|---|---|
| `hypr` | `hyprland.lua`, `hypridle.conf`, `hyprlock.conf` |
| `hyprlid` | `lid-handler.sh`: suspend, or turn the panel off when docked on AC |
| `waybar` | `top.jsonc`, `bottom.jsonc`, shared `style.css` and the power menu |
| `mako`, `kanshi`, `kitty`, `starship`, `bashrc` | one config each |
| `vscode-oss` | `argv.json`, read by Code - OSS, so it only takes effect on Arch |
| `claude` | Claude Code user settings, commands and the status line script |
| `ansible` | the playbook, its roles and the per-distribution vars |

`bootstrap.sh` is the entry point described above; `install.sh` is the interactive
alternative for linking packages by hand. `CLAUDE.md` documents the reload commands for
each program.

## Day to day

Change a config, then reload the program that reads it; the reload commands are in
`CLAUDE.md`. Add a tool by adding a directory with the same `$HOME`-relative layout, then
either rerun `./bootstrap.sh --tags dotfiles` or link it directly:

```bash
stow <pkg>        # link one package
stow -D <pkg>     # unlink it
stow -R <pkg>     # relink after adding or removing files inside it
./install.sh      # interactive: pick packages, choose what happens on a conflict
```

Images go through Git LFS (`.gitattributes`), so `git lfs install` once per machine; the
playbook does this for you.

## Updating

Arch follows the rolling release: `pacman -Syu` for the repos and your AUR helper of choice
for `brave-bin`. The playbook does not update AUR packages; it only builds them when they
are missing.

Ubuntu keeps its Hyprland at the pinned version until you bump it. Edit the entry in
`ansible/vars/Ubuntu.yml` (version, URL, SHA-256) and rerun with `--tags build`; only the
entries whose stamp is missing are rebuilt. Keep the library pins consistent with what the
new Hyprland release requires (its `CMakeLists.txt` lists the minimums). The Arch PKGBUILDs
are a good source for matching sets and their checksums. Never add apt's own hypr*
packages next to the source builds: with `/usr/local` first on the library path, a program
would load two versions of the same library.

The pinned GitHub Actions in `.github/workflows/ci.yml` are kept current by Dependabot.

## Not automated

- **GPU driver.** Hardware-specific; install it before the first login.
- **Hibernation.** batsignal calls `systemctl hibernate` at 5% battery. That needs a swap
  partition at least the size of RAM and either `resume=` on the kernel line or an
  initramfs that finds the image itself. The playbook warns when no swap is active.
- **Docking station.** `kanshi/.config/kanshi/config` disables the laptop panel when `DP-5`
  is present. Another dock shows up under another name; read it from `hyprctl monitors`.
- **Wallpaper.** hyprpaper starts without a config, so the desktop shows Hyprland's default.
  Add `~/.config/hypr/hyprpaper.conf` to the `hypr` package if you want one.
- **Accounts.** Git identity, SSH keys, Claude Code login, browser profiles.

## Security

- **Everything downloaded outside a package manager is pinned.** Source tarballs and fonts
  carry a SHA-256 that the download is checked against; wl-clip-persist is built from a
  commit hash, not a movable tag; AUR builds go through `makepkg`, which checks the
  PKGBUILD's own checksums. Vendor apt repositories are signed by the vendors' keys.
- **Privileges are used where needed and nowhere else.** Builds run as your user; only the
  install step and the files under `/etc` use sudo. `bootstrap.sh` refuses to run as root.
- **Nothing in the repo is secret or machine-specific.** Paths are `$HOME`-relative, the
  VS Code crash reporter is off so it never writes a per-installation id into the tracked
  file, and Claude Code's credentials live next to the linked settings, not in the repo.
- **The lock screen is verified.** The playbook fails if hyprlock's PAM service is missing,
  and suspend, hibernate and the idle timeout all lock the session first.
- **On GitHub:** secret scanning with push protection, a read-only workflow token, actions
  that must be pinned to a commit SHA, Dependabot updates for them, and a rule that stops
  the default branch from being force-pushed or deleted.

Two things the repo does not pin, because their upstreams offer nothing to pin against:
Claude Code's installer and the `brave-bin` PKGBUILD, which the playbook takes from the AUR
at its current revision.

## Continuous integration

Every push runs `.github/workflows/ci.yml`:

- **lint**: `ansible-lint` on the production profile, a playbook syntax check, and
  `shellcheck` on every shell script in the repo.
- **secrets**: gitleaks over the whole history.
- **bootstrap (arch)** and **bootstrap (ubuntu)**: `bootstrap.sh` runs in a blank
  `archlinux:latest` and a blank `ubuntu:26.04` container as an unprivileged user with
  sudo, exactly as on a new machine, then runs a second time and must report zero changes.

Containers have no systemd, GPU or hardware, so the playbook skips enabling services there;
the compilation, the Hyprland config check and every other step run for real. Login
through greetd and hibernation are the two paths CI cannot exercise.

## Troubleshooting

- **A stow conflict stops the run.** The message names the path. Move it away, or diff it
  against the repo version and commit what you want to keep, then rerun.
- **A source build fails on Ubuntu.** The failing task shows the compiler output. The usual
  cause after an Ubuntu update is a missing `-dev` package; add it to `apt_build_packages`
  in `ansible/vars/Ubuntu.yml` and rerun with `--tags build`.
- **The playbook stops with "sudo: a password is required".** `ansible-playbook` was run
  by hand without `-K`, relying on credentials cached by an earlier `sudo`, and they expired
  mid-run. `./bootstrap.sh` asks up front; when running the playbook directly, pass `-K`.
- **greetd shows nothing after reboot.** `journalctl -u greetd` first. On Arch the greeter
  is a Hyprland session, so a broken GPU driver breaks the login screen too; switch to a
  text console and check that `Hyprland` starts by hand. On Ubuntu tuigreet runs on a plain
  console, so a blank screen there points at greetd itself.
- **The verify role lists a missing program.** It is exactly what `hyprland.lua` references
  but could not find; add the package that provides it to the vars file of that distribution.

## License

MIT, see `LICENSE`.
