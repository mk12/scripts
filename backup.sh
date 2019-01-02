#!/bin/bash

set -eufo pipefail

# Periodic backups. Right now, just for Simplenote.
# https://github.com/hiroshi/simplenote-backup

say() {
    echo " * $*"
}

die() {
    echo "$0: $*" >&2
    exit 1
}

[[ $# -eq 0 || $# -eq 1 ]] || die "$#: invalid number of arguments"

if [[ $# -eq 1 ]]; then
    [[ "$1" == "install" ]] || die "$1: invalid argument"

    plist="com.mitchellkember.backup.plist"
    say "Installing launchd $plist"
    cd "$(dirname "$0")"
    [[ "$(basename "$(pwd)")" == "scripts" ]] || die "not in git directory"
    [[ -f "./$plist" ]] || die "$plist: file not found"
    dest="$HOME/Library/LaunchAgents"
    say "Copying to $dest/$plist"
    cp "./$plist" "$dest/$plist"
    say "Loading $dest/$plist"
    launchctl load "$dest/$plist"
    say "Success"
    exit 0
fi

say "Backing up Simplenote in Dropbox"
cd "$PROJECTS" || die "\$PROJECTS not set"
cd simplenote-backup || die "simplenote-backup is not installed"
[[ -n ${SIMPLENOTE_API_TOKEN+x} ]] || die "\$SIMPLENOTE_API_TOKEN not set"
dest=$HOME/Dropbox/Archive/Backups/Simplenote
[[ -d "$dest" ]] || die "$dest does not exist"
temp=$(mktemp -d)
make TOKEN="$SIMPLENOTE_API_TOKEN" BACKUP_DIR="$temp/"
rsync -ac --delete "$temp/" "$dest"
rm -rf "$temp"
