#!/bin/bash

set -Eeufo pipefail
trap 'echo >&2 "$0:$LINENO [$?]: $BASH_COMMAND"' ERR

if [[ -z "$PROJECTS" ]]; then
    echo >&2 "PROJECTS not set"
    exit 1
fi

dir=$PROJECTS/fzf

if [[ -d "$dir" ]]; then
    git -C "$dir" pull
else
    git clone git@github.com:junegunn/fzf.git "$dir"
fi

"$dir/install" --bin
sim install "$dir/bin/fzf"
rsync -a "$dir/man" ~/.local/share
mkdir -p ~/.local/state/fzf
