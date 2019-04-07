#!/bin/bash

set -eufo pipefail

die() {
    echo "$0: $*" >&2
    exit 1
}

# https://apple.stackexchange.com/a/103346
val=$(ioreg -n IODisplayWrangler \
    | grep -i IOPowerManagement \
    | perl -pe 's/^.*DevicePowerState\"=([0-9]+).*$/\1/')
if [[ "$val" == "0" ]]; then
    die "screen is off"
fi

session=$(tmux list-clients | head -n1 | cut -d' ' -f2)
if [[ -z "$session" ]]; then
    die "no tmux session"
fi

tmux split-window -t "$session" rainbowterm set -as \; resize-pane -y 2
echo "changed color preset on $session"
