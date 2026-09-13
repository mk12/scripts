#!/bin/bash

set -Eeufo pipefail
trap 'echo >&2 "$0:$LINENO [$?]: $BASH_COMMAND"' ERR

usage() {
    cat <<EOF
Usage: $0 FORM [YEAR1 YEAR2]

FORM should start with f (form) or i (instructions), e.g. f1040.
Defaults to Y-2 and Y-1 where Y is the current year.
EOF
}

case $# in
    1|3) ;;
    *) usage >&2; exit 1 ;;
esac

case $1 in
    ""|-h|--help) usage; exit ;;
    -*) usage >&2; exit 1 ;;
    *) form=$1 ;;
esac

if [[ $# -eq 3 ]]; then
    a=$2
    b=$3
else
    year=$(date +%Y)
    a=$(( year - 2 ))
    b=$(( year - 1 ))
fi

download() {
    filename=$form--$1.pdf
    if [[ -e "$filename" ]]; then
        echo "$filename already exists"
    else
        download-irs-form "$form" "$1" -s -o "$filename"
    fi
}

cd $HOME/Desktop/taxes-diff
download "$a"
download "$b"

pdf-compare-visual $form--{$a,$b}.pdf -o $form-$a-vs-$b
open $form-$a-vs-$b/
