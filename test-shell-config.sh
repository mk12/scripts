#!/bin/bash

if [[ $# -eq 1 && "$1" == "-e" ]]; then
    readonly nl=$'\n'
    for f in "$PROJECTS"/dotfiles/.{profile,bash{_profile,rc},config/fish/config.fish}; do
        ( set -x; sed -i '' "1s;^;echo $(basename "$f")\\$nl;" "$f" )
    done
    exit
fi

if [[ $# -ne 0 ]]; then
    echo "usage: $0 [-e]" >&2
    exit 1
fi

for args in -c -lc -ic -lic; do
    for shell in fish bash sh; do
        echo ">" "$shell" "$args" "echo hi"
        "$shell" "$args" "echo hi"
        echo
    done
done
