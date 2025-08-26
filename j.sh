#!/bin/bash

set -eufo pipefail

tmp=$(mktemp)
trap 'rm -rf "$tmp"' EXIT

cat <<EOS "$@" - > "$tmp"
r =: 3 : 0
load '$1'
)
ts =: 6!:2 , 7!:2@]
EOS

jcon "$tmp"
