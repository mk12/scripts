#!/bin/bash

# This script is used by the insert_fzf function in config.fish. It works as a
# general preview tool for any file or directory.

set -eufo pipefail

# shellcheck disable=SC2088
[[ $1 == "~/"* ]] && set -- "$HOME${1#\~}"

if [[ -f "$1" ]]; then
    if command -v bat &> /dev/null; then
        bat --plain --color=always -- "$1"
    else
        cat -- "$1"
    fi
elif [[ -d "$1" ]]; then
    if command -v exa &> /dev/null; then
        exa -a --color=always -- "$1"
    else
        ls -a --color=always -- "$1"
    fi
fi
