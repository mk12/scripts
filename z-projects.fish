#!/usr/bin/env fish

# Prints directories in $PROJECTS ordered by z "frecency".

z --list $PROJECTS/ | awk -v base=$PROJECTS/ '
NR == FNR {
    exists[$0] = 1;
    next;
}
{
    sub(base, "", $2);
    sub("/.*", "", $2);
    if (exists[$2] && !seen[$2]++) print $2;
}
' (ls $PROJECTS | psub) -
