#!/bin/bash

set -eufo pipefail

prog=$(basename "$0")

usage() {
    cat <<EOS
Usage: $prog FILE.html ...

Takes HTML files from /messages/inbox in "copy of your Facebook data", parses
message timestamps from them, and plots a histogram.
EOS
}

if [[ $# -eq 0 || "$1" = "-h" || "$1" == "--help" ]]; then
    usage
    exit
fi

tmp=$(mktemp)
trap 'rm -f "$tmp"' EXIT

rg '>((?:Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Nov|Dec) \d\d, 20\d\d \d{1,2}:\d\d:\d\d(am|pm))</div>' \
    -o -r '$1' -I -N -- "$@" > "$tmp"
python3 -c '
import sys
try:
    import plotly.express as px
    import pandas as pd
except ModuleNotFoundError:
    print("please install plotly and pandas: pip3 install plotly pandas",
        file=sys.stderr)
    sys.exit(1)
df = pd.read_csv(sys.argv[1], sep="\t", names=["timestamp"], parse_dates=[0],
    infer_datetime_format=True)
px.histogram(df, x="timestamp").show()
for line in sys.stdin:
    n = int(line.strip())
    px.histogram(df, x="timestamp", nbins=n).show()
' "$tmp"
