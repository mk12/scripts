#!/bin/bash

set -Eeufo pipefail
trap 'echo >&2 "$0:$LINENO [$?]: $BASH_COMMAND"' ERR

if [[ -z "$PROJECTS" ]]; then
    echo >&2 "PROJECTS not set"
    exit 1
fi

clone_or_update() {
    dir="$PROJECTS/$1"
    if [[ -d "$dir" ]]; then
        git -C "$dir" pull
    else
        git clone "git@github.com:mk12/$1.git" "$dir"
    fi
}

clone_or_update base16-kitty
clone_or_update base16-solarized-scheme

cd "$PROJECTS/base16-kitty"
pip3 install pybase16-builder
./register.sh ../base16-solarized-scheme
./update.sh
./build.sh
