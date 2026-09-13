#!/bin/bash

set -Eeufo pipefail
trap 'echo >&2 "$0:$LINENO [$?]: $BASH_COMMAND"' ERR

usage() {
    cat <<EOF
Usage: $0

Build caddy for hex

Options:
    -v VERSION  Caddy version (default: latest)
    -x VERSION  xcaddy version (default: existing)
EOF
}

v=latest
x=

while [[ $# -gt 0 ]]; do
    arg=$1; shift
    case $arg in
        -h|--help|"") usage; exit ;;
        -v) v=$1; shift ;;
        -x) x=$1; shift ;;
        *) usage >&2; exit 1 ;;
    esac
done

run() {
    echo "> $*"
    "$@"
}

if ! command -v xcaddy &> /dev/null; then
    echo >&2 "xcaddy not found; please pass -x VERSION to install xcaddy"
    exit 1
fi

if [[ -n "$x" ]]; then
    echo "Installing xcaddy $x"
    run mkdir ~/Downloads/xcaddy-$x
    run cd ~/Downloads/xcaddy-$x
    name=xcaddy_${x}_mac_arm64
    tarball=$name.tar.gz
    if ! [[ -e "$name" ]]; then
        if ! [[ -e "$tarball" ]]; then
            run curl -LO https://github.com/caddyserver/xcaddy/releases/download/v$x/$tarball
        fi
        run tar -xzf "$tarball"
    fi
    sim install --move "$name/xcaddy"
fi

echo "Building caddy $v"
run mkdir ~/Downloads/caddy-$v
run cd ~/Downloads/caddy-$v
run env GOOS=linux GOARCH=amd64 xcaddy build "$v" \
    --with github.com/caddy-dns/nfsn \
    --with github.com/mholt/caddy-l4 \
    --with github.com/caddyserver/transform-encoder \
    --with github.com/hslatman/caddy-crowdsec-bouncer/http@main \
    --with github.com/hslatman/caddy-crowdsec-bouncer/appsec@main \
    --with github.com/hslatman/caddy-crowdsec-bouncer/layer4@main

echo "Copying to hex"
run scp ~/Downloads/caddy-$v/caddy hex:

echo "Now manually move it to /usr/bin/caddy.custom"
