#!/bin/bash

set -eufo pipefail

prog=$(basename "$0")
plist="com.mitchellkember.backup.plist"
dest_plist="$HOME/Library/LaunchAgents/$plist"
backup_dest="$HOME/Dropbox/Archive/Backups/Simplenote"

install=false

say() {
    echo " * $*"
}

die() {
    echo "$prog: $*" >&2
    exit 1
}

usage() {
    cat <<EOS
usage: $prog [-hi]

backup up Simplenote to Dropbox using hiroshi/simplenote-backup

options:
  -h  show this help message
  -i  install a launchd agent for this script
EOS
}

do_install() {
    say "Installing launchd $plist"
    cd "$(dirname "$0")"
    [[ "$(basename "$(pwd)")" == "scripts" ]] || die "not in git directory"
    [[ -f "./$plist" ]] || die "$plist: file not found"
    say "Copying to $dest_plist"
    cp "./$plist" "$dest_plist"
    say "Loading $dest_plist"
    launchctl load "$dest_plist"
    say "Success"
}

do_backup() {
    say "Backing up Simplenote in Dropbox"
    cd "$PROJECTS" || die "\$PROJECTS not set"
    cd simplenote-backup || die "simplenote-backup is not installed"
    [[ -n ${SIMPLENOTE_API_TOKEN+x} ]] || die "\$SIMPLENOTE_API_TOKEN not set"
    [[ -d "$backup_dest" ]] || die "$backup_dest does not exist"
    temp=$(mktemp -d)
    make TOKEN="$SIMPLENOTE_API_TOKEN" BACKUP_DIR="$temp/"
    echo "skippin rsync"
    rsync -ac --delete "$temp/" "$backup_dest"
    rm -rf "$temp"
}

main() {
    if [[ "$install" == true ]]; then
        do_install
    else
        do_backup
    fi
}

while getopts "hi" opt; do
    case $opt in
        h) usage; exit 0 ;;
        i) install=true ;;
        *) exit 1 ;;
    esac
done
shift $((OPTIND - 1))
[[ $# -eq 0 ]] || die "too many arguments"

main
