#!/bin/bash

if ! [[ -n "$TMUX" ]]; then
    echo "not in a tmux session" >&2
    exit 1
fi

TMUX= tmux attach -c "$(pwd)" -t . \; detach < /dev/null > /dev/null 2>&1 || :
