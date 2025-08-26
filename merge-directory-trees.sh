#!/bin/bash

set -Eeufo pipefail
trap 'echo >&2 "$0:$LINENO [$?]: $BASH_COMMAND"' ERR

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

list() {
    fd . --type f --unrestricted --exclude '.DS_Store' --base-directory "$1" | sort
}

size() {
    stat -f%z "$1"
}

run() {
    echo "> $@"
    if [[ $dry_run = false ]]; then
        "$@"
    fi
}

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

for dir in "${dirs[@]}"; do
    echo "Merging: $dir -> $dest"
    list "$dir" > "$tmp/a"
    list "$dest" > "$tmp/b"
    while read -r file; do
        if ! run cmp "$dir/$file" "$dest/$file"; then
            echo >&2 "$file differs"
            exit 1
        fi
        run rm "$dir/$file"
    done < <(comm -12 "$tmp/a" "$tmp/b")
    while read -r file; do
        run mkdir -p "$dest/$(dirname "$file")"
        run mv "$dir/$file" "$dest/$file"
    done < <(comm -23 "$tmp/a" "$tmp/b")
done
