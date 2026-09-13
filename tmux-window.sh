#!/bin/bash

# https://github.com/junegunn/fzf/wiki/Examples#tmux

[[ -n "$TMUX" ]] && change="switch-client" || change="attach-session"
window=$(tmux list-windows -a -F "#{session_name}:#{window_index} #{window_name}" 2>/dev/null \
    | fzf-tmux -u 50% --layout=reverse --exit-0)
tmux "$change" -t "${window%% *}" || echo "No windows found."
