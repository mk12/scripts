#!/bin/bash

set -Eeufo pipefail
trap 'echo >&2 "$0:$LINENO [$?]: $BASH_COMMAND"' ERR

tmp=$(mktemp)
trap 'rm -rf "$tmp"' EXIT

cat <<EOS "$@" - > "$tmp"
r =: 3 : 0
load '$1'
)
ts =: 6!:2 , 7!:2@]
EOS

jcon "$tmp"
