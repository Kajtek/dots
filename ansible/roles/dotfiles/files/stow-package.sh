#!/usr/bin/env bash
# Stow one package non-interactively. Run from the repo root so .stowrc supplies --target
# and --no-folding. A plain file already sitting where a link should go (the distro's
# default ~/.bashrc) is moved to <file>.pre-dots once; anything else in the way (a foreign
# symlink, a directory, a second backup) is left alone and reported as an error, because
# guessing there would destroy something. Prints CHANGED when a file moved or a link was
# made, so Ansible can report it.
set -euo pipefail
pkg=$1
changed=

conflicts=$(stow --no "$pkg" 2>&1 | sed -n 's/.*over existing target \(.*\) since neither a link nor a directory.*/\1/p') || true
while IFS= read -r target; do
    [[ -n $target ]] || continue
    path=$HOME/$target
    if [[ -f $path && ! -L $path && ! -e $path.pre-dots ]]; then
        mv "$path" "$path.pre-dots"
        echo "moved $target to $target.pre-dots"
        changed=1
    else
        echo "$pkg: cannot stow over $path; move it away and rerun" >&2
        exit 1
    fi
done <<< "$conflicts"

# A simulated stow lists the links it would create; none means the package is already in place.
# (Captured first: piping into grep -q would let grep close the pipe early and, with pipefail,
# turn a multi-line answer into a false "unchanged".)
plan=$(stow --no --verbose "$pkg" 2>&1)
if grep -q '^LINK: ' <<< "$plan"; then
    changed=1
fi
# Restow regardless so links to files removed from the package are cleaned up.
stow --verbose=0 --restow "$pkg"
[[ -z $changed ]] || echo CHANGED
