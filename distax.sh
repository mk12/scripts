#!/bin/bash

set -Eeufo pipefail
trap 'echo >&2 "$0:$LINENO [$?]: $BASH_COMMAND"' ERR

input=$(pbpaste)

gawk '
match($0, /^(.* USD )([0-9]+\.[0-9]+)$/, m) {
    if (NR == FNR) {
        items[i++] = m[2];
        subtotal += m[2];
    } else {
        printf "%s%.2f\n", m[1], items[i++];
    }
    next;
}
match($0, / USD -([0-9]+\.[0-9]+)$/, m) {
    if (NR == FNR) {
        total = m[1];
        for (j = 0; j < i; j++) {
            items[j] = items[j] / subtotal * total;
        }
        i = 0;
    } else {
        print;
    }
    next;
}
NR != FNR {
    print;
}
END {
    printf "Distributed %.2f\n", total - subtotal > "/dev/stderr";
}
' <(echo "$input") <(echo "$input") | yank
