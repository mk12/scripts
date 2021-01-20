#!/bin/bash

set -eufo pipefail

# Need this because it's run from launchd.
source ~/.profile

readonly prog=$(basename "$0")
readonly plist="com.mitchellkember.backup.plist"
readonly dest_plist="$HOME/Library/LaunchAgents/$plist"
readonly backup_dir="$HOME/Dropbox/Archive/Backups"

temp_dir=

# Options
install=false
only=

usage() {
    cat <<EOS
usage: $prog [-hi]

This script backs things up to Dropbox:

* Private git repositories, using git bundle
* Simplenote, using hiroshi/simplenote-backup

Options:
    -h  show this help message
    -i  install a launchd agent for this script
    -r  back up only repositories
    -s  back up only Simplenote
EOS
}

say() {
    echo " * $*"
}

die() {
    echo "$prog: $*" >&2
    exit 1
}

install_launchd() {
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

backup() {
    say "Date: $(date)"
    temp_dir=$(mktemp -d)
    if [[ -z $only || $only == repos ]]; then
        backup_repos
    fi
    if [[ -z $only || $only == simplenote ]]; then
        backup_simplenote
    fi
    rm -rf "$temp_dir"
}

backup_repos() {
    backup_git_repo finance
}

backup_git_repo() {
    say "Backing up $1.git in Dropbox"
    cd "$PROJECTS/$1"
    name="$1.gitbundle"
    git bundle create "$temp_dir/$name" master
    rsync -ac "$temp_dir/$name" "$backup_dir/$name"
}

backup_simplenote() {
    say "Backing up Simplenote in Dropbox"
    cd "$PROJECTS" || die "\$PROJECTS not found"
    cd simplenote-backup || die "simplenote-backup not installed"
    [[ -n ${SIMPLENOTE_API_TOKEN+x} ]] || die "\$SIMPLENOTE_API_TOKEN not set"
    [[ -d "$backup_dir" ]] || die "$backup_dir not found"
    dir="$temp_dir/simplenote"
    make TOKEN="$SIMPLENOTE_API_TOKEN" BACKUP_DIR="$dir/"
    rsync -ac --delete "$dir/" "$backup_dir/Simplenote"
}

while getopts "hirs" opt; do
    case $opt in
        h) usage; exit 0 ;;
        i) install=true ;;
        r) only=repos ;;
        s) only=simplenote ;;
        *) exit 1 ;;
    esac
done
shift $((OPTIND - 1))
[[ $# -eq 0 ]] || die "too many arguments"

if [[ $install == true ]]; then
    install_launchd
else
    backup
fi
