#!/bin/bash

set -Eeufo pipefail
trap 'echo >&2 "$0:$LINENO [$?]: $BASH_COMMAND"' ERR

usage() {
    cat <<EOS
$0 [-hne] FILE

Render <!-- knitting chart: --> comments to SVG.

Options:
    -n  Dry run (print rather than overwriting)
    -e  Watch for changes and rerun with entr
EOS
}

grid_script=$PROJECTS/mk12-scripts/make-svg-grid.py

flags='-i inplace'
entr=false

while getopts "hne" opt; do
    case $opt in
        h) usage; exit 0;;
        n) flags= ;;
        e) entr=true ;;
        *) exit 1 ;;
    esac
done
shift $((OPTIND - 1))

replace() {
    files=("${@:2}")
    if [[ "${files[0]}" == "$grid_script" ]]; then
        files=()
        if ! [[ -f /tmp/render-knitting-charts-last.txt ]]; then
            return
        fi
        while read -r line; do
            files+=("$line")
        done < /tmp/render-knitting-charts-last.txt
    else
        printf "%s\n" "${files[@]}" > /tmp/render-knitting-charts-last.txt
    fi
    gawk $1 -v grid_script="$grid_script" '
BEGINFILE { s = 0; }
/^<!--$/ { s = 1; print; next; }
s == 1 {
    if (match($0, /^knitting-chart: (.*)$/, m)) {
        args = m[1];
        s = 2;
        chart = "";
    } else {
        s = 0;
    }
    print; next;
}
s == 2 {
    if (/^-->$/) {
        s = 3;
    } else {
        chart = chart $0 "\n";
    }
    print; next;
}
s == 3 {
    if (/^<figure>$/) {
        s = 4;
    }
    print;
    next;
}
s == 4 {
    if (/^<\/figure>$/) {
        print chart > "/tmp/knitting-chart.txt";
        system(grid_script " " args " --chart /tmp/knitting-chart.txt");
        print;
        s = 0;
    }
    next;
}
{ print; }
' "${files[@]}"
}

if [[ $entr = true ]]; then
    export -f replace
    export grid_script
    printf "%s\n" "$grid_script" "$@" \
        | SHELL=/bin/bash entr -s "replace '$flags' \$0"
else
    replace "$flags" "$@"
fi
