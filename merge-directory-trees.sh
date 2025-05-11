#!/bin/bash

set -eufo pipefail

usage() {
    cat <<EOS
Usage: $0 [-n] DIR ... DEST

Merges directories DIR into DEST.

Options:
    -n, --dry-run  Just print what it would do
EOS
}

dry_run=false

dirs=()
for arg; do
    case $arg in
        -h|--help) usage; exit 0 ;;
        -n|--dry-run) dry_run=true ;;
        -*) usage >&2; exit 1 ;;
        *) dirs+=("$arg") ;;
    esac
done

n=${#dirs[@]}
if [[ $n -lt 2 ]]; then
    usage >&2; exit 1
fi

dest=${dirs[$n-1]}
unset 'dirs[$n-1]'

rsync_list() {
    rsync --dry-run -av --exclude .DS_Store "$@" | awk '
        /^sending incremental file list$/ { p = 1; next; }
        /^$/ { exit; }
        p { print; }
    '
}

for dir in "${dirs[@]}"; do
    echo "Merging: $dir -> $dest"
    while read -r line; do
        if [[ ! -d "$dest/$line" ]]; then
            echo >&2 "error: file $line already exists"
            exit 1
        fi
    done < <(rsync_list --existing "$dir/" "$dest/")
    while read -r line; do
        if [[ ! -e "$dest/$line" ]]; then
            echo "would copy $line"
        fi
    done < <(rsync_list --ignore-existing "$dir/" "$dest/")
    break
done
