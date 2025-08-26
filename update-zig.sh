#!/bin/bash

set -Eeufo pipefail
trap 'echo >&2 "$0:$LINENO [$?]: $BASH_COMMAND"' ERR

die() {
    echo >&2 "$@"
    exit 1
}

run() {
    echo >&2 "$@"
    "$@"
}

install() {
    name=$1
    key=${2#key=}
    dir=${3#dir=}
    index_url=$4
    run cd ~/Documents/"$name"
    fd -q -d 1 -e tar -e xz && die "There is already a .tar or .xz file"
    read -r url shasum < <(
        run curl -sL "$index_url" \
        | run jq -r $key'."aarch64-macos" | "\(.tarball) \(.shasum)"')
    id=${url##*/}
    id=${id%.tar.xz}
    [[ -z "$id" ]] && die "Failed to extract id"
    [[ -n "$dir" ]] && mkdir "$id"
    run curl -LO "$url"
    run shasum --check -a 256 <<< "$shasum  $id.tar.xz"
    run xz -d "$id.tar.xz"
    run tar ${dir:+-C "$id"} -xf "$id.tar"
    run rm "$id.tar"
    run sim i -f "$id/$name"
}

if [[ ${1-zig} == zig ]]; then
    install zig key=.master dir= https://ziglang.org/download/index.json
fi

if [[ ${1-zls} == zls ]]; then
    zig_version=$(run zig version)
    zig_version=${zig_version//+/%2B}
    install zls key= dir=yes "https://releases.zigtools.org/v1/zls/select-version?zig_version=$zig_version&compatibility=only-runtime"
fi
