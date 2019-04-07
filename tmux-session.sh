#!/bin/bash

# https://github.com/junegunn/fzf/wiki/Examples#tmux

[[ -n "$TMUX" ]] && change="switch-client" || change="attach-session"
session=$(tmux list-sessions -F "#{session_name}" 2>/dev/null \
    | fzf-tmux -u 50% --layout=reverse --exit-0)
tmux "$change" -t "$session" || echo "No sessions found."
