#!/bin/bash

set -Eeufo pipefail
trap 'echo >&2 "$0:$LINENO [$?]: $BASH_COMMAND"' ERR

supported=(
    xterm-kitty
    tmux-256color
)

usage() {
    cat <<EOS
Usage: $0 [NAME]

Install terminfo entries

Arguments:
    NAME  The terminfo to install (if omitted, installs all)

Supported terminfos:
    ${supported[*]}
EOS
}

tmp=$(mktemp)
trap 'rm "$tmp"' EXIT

die() {
    echo >&2 "$0: $*"
    exit 1
}

ensure() {
    if [[ $# -gt 1 ]]; then
        for name; do
            ensure "$name"
        done
        return
    fi

    # Clear TERMINFO to avoid a false positive for xterm-kitty when running
    # within kitty (we still want to install it in ~/.terminfo, otherwise it
    # doesn't work when ssh'ing to localhost).
    if TERMINFO="" infocmp "$1" &> /dev/null; then
        echo "$1 is already installed"
        return
    fi

    case $1 in
        xterm-kitty)
            if [[ -z ${KITTY_PID+x} ]]; then
                cat >&2 <<EOS
Cannot install $1 because we are not (directly) in kitty.
If this is a remote machine, run this locally to install $1 on it:

    kitty +kitten ssh $(whoami)@$(hostname)
EOS
                return
            fi
            infocmp -a "$1" > "$tmp"
            tic -x -o ~/.terminfo "$tmp"
            ;;

        tmux-256color)
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
            ;;

        *) die "$1: unsupported terminfo"
    esac
    echo "Installed $1"
}

case $# in
    0)
        ensure "${supported[@]}"
        ;;
    *)
        case $1 in
            -h|--help|help) usage ;;
            *) ensure "$@" ;;
        esac
        ;;
esac
