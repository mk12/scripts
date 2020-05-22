#!/bin/bash

if [[ $# -eq 1 && "$1" == "-e" ]]; then
    for f in ~/.{shellrc,bashrc,profile,bash_profile,config/fish/config.fish}; do
        ( set -x; sed -i '' "1iecho $f" )
    done
    echo "to clean: cd $PROJECTS/dotfiles && git clean -f"
    return
fi

for args in -c -lc -ic -lic; do
    for shell in fish bash sh; do
        echo ">" "$shell" "$args" "echo hi"
        "$shell" "$args" "echo hi"
        echo
    done
done
