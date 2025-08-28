#!/bin/bash

set -Eeufo pipefail
trap 'echo >&2 "$0:$LINENO [$?]: $BASH_COMMAND"' ERR

# Prints directories in $PROJECTS ordered by z "frecency".
awk -v base=$PROJECTS/ '
NR == FNR { exists[$0] = 1; next; }
{
    sub(base, "");
    sub("/.*", "");
    if (exists[$0] && !seen[$0]++) print;
}
' <(ls $PROJECTS) <(zoxide query --list $PROJECTS/)
