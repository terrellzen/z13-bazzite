#!/usr/bin/env bash
set -euo pipefail
(( EUID != 0 )) || exit 0
state_dir=${XDG_STATE_HOME:-$HOME/.local/state}/z13-setup
mkdir -p -- "$state_dir"
exec 9>"$state_dir/desktop.lock"
flock -x 9
[[ ! -e $state_dir/desktop-offered ]] || exit 0
# xdg-user-dir handles localized paths and the user's user-dirs.dirs settings.
desktop=$(xdg-user-dir DESKTOP) || exit 0
if [[ -n $desktop && $desktop == /* && $desktop != "$HOME" && -d $desktop && -w $desktop ]]; then
    target=$desktop/z13-first-time-setup.desktop
    # Noclobber also protects existing symlinks. Do not alter existing launchers.
    if (set -o noclobber; cat /usr/share/applications/z13-first-time-setup.desktop > "$target") 2>/dev/null; then
        chmod u+x -- "$target"
    fi
fi
# Record the offer even if the desktop is disabled/unavailable. The menu entry
# remains available, and deleting the desktop shortcut is a lasting choice.
touch -- "$state_dir/desktop-offered"
