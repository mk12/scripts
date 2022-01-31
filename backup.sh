#!/bin/bash

set -eufo pipefail

# Need to source .profile because it's run from launchd.
# shellcheck source=../dotfiles/.profile
source ~/.profile

prog=$(basename "$0")
plist="com.mitchellkember.backup.plist"
dest_plist="$HOME/Library/LaunchAgents/$plist"
backup_dir="$HOME/Dropbox/Backups"

temp_dir=

# Options
install=false
only=

usage() {
    cat <<EOS
Usage: $prog [-hi]

This script backs things up to Dropbox:

* Private git repositories, using git bundle
* Obsidian notes

Options:
    -h  Show this help message
    -i  Install a launchd agent for this script
    -r  Back up only repositories
    -o  Back up only Obsidian
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
    say "Unloading old $dest_plist"
    launchctl unload "$dest_plist" || :
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
    if [[ -z $only || $only == obsidian ]]; then
        backup_obsidian
    fi
    rm -rf "$temp_dir"
}

backup_repos() {
    backup_git_repo journal
    backup_git_repo finance
}

backup_git_repo() {
    say "Backing up $1.git in Dropbox"
    cd "$PROJECTS/$1"
    name="$1.gitbundle"
    git bundle create "$temp_dir/$name" main
    rsync -ac "$temp_dir/$name" "$backup_dir/$name"
}

backup_obsidian() {
    say "Backing up Obsidian vault in Dropbox"
    # Don't pass --delete
    rsync -ac \
        "$HOME/Library/Mobile Documents/iCloud~md~obsidian/Documents/Notes" \
        "$backup_dir/Obsidian"
}

while getopts "hiro" opt; do
    case $opt in
        h) usage; exit 0 ;;
        i) install=true ;;
        r) only=repos ;;
        o) only=obsidian ;;
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
