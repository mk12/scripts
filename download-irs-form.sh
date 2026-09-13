#!/bin/bash

set -Eeufo pipefail
trap 'echo >&2 "$0:$LINENO [$?]: $BASH_COMMAND"' ERR

usage() {
    cat <<EOF
Usage: $0 FORM [YEAR] [CURL_ARGS ...]

FORM should start with f (form) or i (instructions), e.g. f1040.
Defaults to last year.
EOF
}

case ${1-} in
    ""|-h|--help) usage; exit ;;
    -*) usage >&2; exit 1 ;;
    *) form=$1 ;;
esac

current_year=$(date +%Y)

form=$1; shift
if [[ "$1" = 2* ]]; then
    year=$1; shift
else
    year=$(( current_year - 1 ))
fi

if [[ "$year" -eq $(( current_year - 1 )) ]]; then
    url="https://www.irs.gov/pub/irs-pdf/$form.pdf"
else
    url="https://www.irs.gov/pub/irs-prior/$form--$year.pdf"
fi

curl -L "$url" "$@"
