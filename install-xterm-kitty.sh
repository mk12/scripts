#!/bin/bash

set -eufo pipefail

prog=$(basename "$0")

usage() {
    cat <<EOS
Usage: $prog [user@host]

Install xterm-kitty terminfo on the local machine or a remote one.
EOS
}

die() {
    echo "$prog: $*" >&2
    exit 1
}

[[ -z ${KITTY_PID+x} ]] && die "must run from kitty.app"

case $# in
    0)
        tmp=$(mktemp)
        infocmp -a xterm-kitty > "$tmp"
        tic -x -o ~/.terminfo "$tmp"
        rm "$tmp"
        ;;
    1)
        case $1 in
            -h|--help|help) usage; exit ;;
        esac
        infocmp -a xterm-kitty | ssh "$1" "
cat > ~/xterm-kitty-terminfo
tic -x -o ~/.terminfo ~/xterm-kitty-terminfo
rm ~/xterm-kitty-terminfo
"
        ;;
    *) usage >&2; exit 1 ;;
esac
