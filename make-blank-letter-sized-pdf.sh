#!/bin/bash

set -Eeufo pipefail
trap 'echo >&2 "$0:$LINENO [$?]: $BASH_COMMAND"' ERR

usage() {
    cat <<EOF
Usage: $0 FILENAME

Write a blank letter-sized PDF to FILENAME
EOF
}

case $1 in
    ""|-h|--help) usage; exit ;;
    -*) usage >&2; exit 1 ;;
esac

convert xc:none -page Letter "$1"
