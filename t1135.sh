#!/bin/bash

set -Eeufo pipefail
trap 'echo >&2 "$0:$LINENO [$?]: $BASH_COMMAND"' ERR

usage() {
    cat <<EOS
usage: $0 [-h] YEAR END USDCAD

This script calculates maximum account balances for foreign (outside Canada)
accounts during a year, for T1135 filing.

YEAR is a 4-digit year, like 2019.
END is the (exclusive) date to end on. If you want to consider all of 2019, you
should enter 2020. If you want to stop in the middle of the year, you can do so.
USDCAD is the exchange rate X such that CAD = USD * X

Look up exchange rates here:
https://www.bankofcanada.ca/rates/exchange/annual-average-exchange-rates/

Note: Unlike FBAR, T1135 uses the average exchange rate.
Note: Unlike FBAR, T1135 considers a single max day, not the sum of the
individual maxes of each account. HOWEVER, this script conservatively does the
latter (which will always be the same or higher), since I created this based on
the FBAR script and I don't want to spend a lot of time on it.
EOS
}

readonly accounts=(
    "Assets:BOA Checking"
    # "Assets:TD Bank Checking"
)

main() {
    year=$1
    end=$2
    exchange=$3
    echo "Using USDCAD: $exchange"
    echo
    combined=0
    # NOTE: Really, it should also check bal at the start of the year in case
    # there are no transactions during the year.
    for acct in "${accounts[@]}"; do
        format='{"date":"%(format_date(date))","total":"%(scrub(display_total))"}\n'
        jqexpr="
map(
    select(.date | startswith(\"$year-\"))
    | .value = (.total
                | gsub(\"[^0-9.]\"; \"\")
                | if . == \"\" then 0 else tonumber end)
) | max_by(.value)
"
        res=$(ledger reg -e "$end" "^$acct\$" \
                --date-format '%Y-%m-%d' --format "$format" \
                | jq -s "$jqexpr")
        date=$(jq -r '.date' <<< "$res")
        total=$(jq -r '.total' <<< "$res")
        value=$(jq -r '.value' <<< "$res")
        if [[ "$total" == 'USD'* ]]; then
            cad=$(bc <<< "scale=2; $value * $exchange")
        else
            echo "$0: unexpected record: $res" >&2
            exit 1
        fi
        printf "%-25s %15s %10s %20s on %s\n" \
            "$acct" "$total" "($value)" "[CAD $cad]" "$date"
        combined=$(bc <<< "scale=2; $combined + $cad")
    done
    echo "---------------------------------------------------------------------"
    printf "Aggregate: %15s\n" "CAD $combined"
}

while getopts "h" opt; do
    case $opt in
        h) usage; exit 0;;
        *) exit 1 ;;
    esac
done
shift $((OPTIND - 1))

if [[ $# -ne 3 ]]; then
    usage
    exit 1
fi

main "$@"
