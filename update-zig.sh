#!/bin/bash

set -eufo pipefail

die() {
    echo >&2 "$@"
    exit 1
}

run() {
    echo >&2 "$@"
    "$@"
}

run cd ~/Documents/Zig
fd -q -d 1 -e tar -e xz && die "There is already a .tar or .xz file"
url=$(run curl -sL https://ziglang.org/download/index.json \
    | run jq -r '.master."aarch64-macos".tarball')
name=${url##*/}
name=${name%.tar.xz}
[[ -z "$name" ]] && die "Failed to extract name"
run curl -LO "$url"
run xz -d "$name.tar.xz"
run tar xf "$name.tar"
run rm "$name.tar"
run sim i -f "$name/zig"

run cd "$(sim path)"
run rm zls
run curl -LO https://zig.pm/zls/downloads/aarch64-macos/bin/zls
run chmod +x zls
