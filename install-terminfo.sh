#!/bin/bash

set -eufo pipefail

usage() {
    cat <<EOS
Usage: $0

Install some terminfo:

- xterm-kitty
- tmux-256color
- tmux-direct
EOS
}

if [[ $# -ne 0 ]]; then
    usage
    exit 1
fi

tmp=$(mktemp)
trap 'rm "$tmp"' EXIT

has() {
    # Clear TERMINFO to avoid a false positive for xterm-kitty when running
    # within kitty (we still want to install it in ~/.terminfo, otherwise it
    # doesn't work when ssh'ing to localhost).
    TERMINFO="" infocmp "$1" &> /dev/null || return 1
}

if ! has xterm-kitty; then
    if [[ -z ${KITTY_PID+x} ]]; then
        cat >&2 <<EOS
Cannot install xterm-kitty because we are not (directly) in kitty.
If this is a remote machine, run this locally to install xterm-kitty here:

    kitty +kitten ssh $(whoami)@$(hostname)
EOS
    else
        infocmp -a xterm-kitty > "$tmp"
        tic -x -o ~/.terminfo "$tmp"
        echo "Installed xterm-kitty"
    fi
fi

tmux_terminfo() {
    has "$1" && return
    case $(uname -s) in
        Darwin) ;;
        *) echo >&2 "I only know how to install $1 on macOS"; return ;;
    esac
    prefix=$(brew --prefix ncurses)
    if ! [[ -d "$prefix" ]]; then
        brew install ncurses
    fi
    "$prefix/bin/infocmp" -A "$prefix/share/terminfo" "$1" > "$tmp"
    tic -o ~/.terminfo "$tmp"
    echo "Installed $1"
}

tmux_terminfo tmux-256color
tmux_terminfo tmux-direct
