#!/bin/bash

set -Eeufo pipefail
trap 'echo >&2 "$0:$LINENO [$?]: $BASH_COMMAND"' ERR

journal=$(ls $PROJECTS/journal/20*.md | sort -R | head -n1)
line=$(((RANDOM % $(wc -l < "$journal")) + 1))
nvim "$journal:$line"
