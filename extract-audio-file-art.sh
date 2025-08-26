#!/bin/bash

set -Eeufo pipefail
trap 'echo >&2 "$0:$LINENO [$?]: $BASH_COMMAND"' ERR

if [[ -d "$1" ]]; then
    set -- "$(find "$1" -name '*.m4a' -o -name '*.mp3' | head -n1)"
fi

# Not matching ^ because there is a BOM :/
path=$(AtomicParsley "$1" -E 2>&1 \
| gawk 'match($0, /Extracted artwork to file: (.*)$/, m) { print m[1]; }')

if [[ -n "$path" ]]; then
    dir=$(dirname "$path")
    ext=$(tr '[:upper:]' '[:lower:]' <<< "${path##*.}")
    case $ext in
        jpeg) ext=jpg ;;
    esac
    mv "$path" "$dir/cover.$ext"
else
    echo >&2 "warning: no album art for $1"
fi
