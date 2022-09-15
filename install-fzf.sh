#!/bin/bash

set -eufo pipefail

dir="$PROJECTS/fzf"

if [[ -d "$dir" ]]; then
    git -C "$dir" pull
else
    git clone git@github.com:junegunn/fzf.git "$dir"
fi

"$dir/install" --bin
sim install "$dir/bin/fzf"
rsync -a "$dir/man" ~/.local/share
mkdir -p ~/.local/state/fzf
