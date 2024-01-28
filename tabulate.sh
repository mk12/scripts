#!/bin/bash

set -eufo pipefail

usage() {
    cat <<EOS
Usage: $0 [-r ROWS] [-c COLS] [-t]

Convert flat lines to TSV

Options:
    -r ROWS  Output number of rows
    -c COLS  Output number of columns
    -t       Transpose lines
EOS
}

rows=
cols=
trans=

args=()

while [[ $# -gt 0 ]]; do
    while [[ $# -gt 0 && "$1" != -* ]]; do
        args+=("$1")
        shift
    done
    while getopts "hr:c:t" opt; do
        case $opt in
            h) usage; exit ;;
            r) rows=$OPTARG ;;
            c) cols=$OPTARG ;;
            t) trans=1 ;;
            *) exit 1 ;;
        esac
    done
    shift $((OPTIND - 1))
done

if [[ -z "$rows" && -z "$cols" ]]; then
    echo >&2 "error: must provide -r or -c"
    exit 1
fi

gawk -v rows="$rows" -v cols="$cols" -v trans="$trans" '
{ lines[FNR] = $0; }
ENDFILE {
    x = rows + cols;
    if (FNR % x != 0) print "warning: " FNR " not divisible by " x;
    if (rows == "") rows = int(FNR / cols);
    if (cols == "") cols = int(FNR / rows);
    for (r = 0; r < rows; r++) {
        for (c = 0; c < cols; c++) {
            if (trans) i = c*rows + r + 1
            else i = r*cols + c + 1;
            printf "%s", lines[i];
            if (c != cols - 1) printf "\t";
        }
        printf "\n";
    }
}
' "${args[@]+"${args[@]}"}"
