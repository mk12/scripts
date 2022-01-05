#!/bin/bash

# This script is used by the insert_fzf function in config.fish. The fzf reload
# action cannot maintain state (e.g. to toggle something), so instead this
# script stores the state in a temporary file.

set -eufo pipefail

tmp=$1

if [[ "$2" == init ]]; then
    root=$3
    type=$4
    hidden=0
    ignore=0
else
    {
        read -r -d: root;
        read -r -d: type;
        read -r -d: hidden;
        read -r -d: ignore;
    } < "$tmp"
fi

case $2 in
    init) ;;
    file|directory|z) type=$2 ;;
    toggle-hidden) ((hidden ^= 1)) ;;
    toggle-ignore) ((ignore ^= 1)) ;;
    up)
        case $root in
            ""|.) root=.. ;;
            ..*)
                if [[ "$(basename "$root")" == .. ]]; then
                    root=$root/..
                else
                    root=$(dirname "$root")
                fi
                ;;
            *) root=$(dirname "$root") ;;
        esac
        ;;
    down)
        dir=${3/#\~/$HOME}
        if [[ -d "$dir" ]] || dir=$(dirname "$dir") && [[ -d "$dir" ]]; then
            root=$dir
            [[ "$type" == z ]] && type=directory
        fi
        ;;
    *) echo "$0: $2: invalid command" >&2; exit 1 ;;
esac

[[ "$root" == . ]] && root= 

echo "$root:$type:$hidden:$ignore:" > "$tmp"

if [[ "$type" == z ]]; then
    fish -c "z -l" | awk "{sub(\"^$HOME/\", \"~/\", \$2); print \$2}"
    exit
fi 

args=(--type "$type" --type symlink --follow --exclude .git)
[[ -z "$root" ]] && args+=(--strip-cwd-prefix)
[[ "$hidden" -eq 1 ]] && args+=(--hidden)
[[ "$ignore" -eq 1 ]] && args+=(--no-ignore)
args+=(-- .)
[[ -n "$root" ]] && args+=("$root")

fd "${args[@]}"
