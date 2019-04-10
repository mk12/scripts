#!/bin/bash

set -eufo pipefail

die() {
    echo "$0: $*" >&2
    exit 1
}

echo "$(date): running autorainbow"

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

pane_id=$(tmux split-window -P -F "#{pane_id}" \
    -d -t "$session" rainbowterm set -as)
tmux resize-pane -t "$pane_id" -y 2
# Wait for it to write to smart_history.
sleep 2
preset=$(tail -n1 ~/.local/share/rainbowterm/smart_history)
echo "$(date): tmux session $session: changed preset to $preset"
