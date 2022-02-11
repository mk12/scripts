#!/bin/bash

set -eufo pipefail

usage() {
    cat <<EOS
usage: $0 [-h] YEAR USDCAD

This script calculates maximum account balances for foreign (outside U.S.)
accounts during a year, for FBAR filing.

YEAR is a 4-digit year, like 2019.
USDCAD is the exchange rate X such that CAD = USD * X

Look up exchange rates here:
https://fiscaldata.treasury.gov/datasets/treasury-reporting-rates-exchange/treasury-reporting-rates-of-exchange

Note: Unlike T1135, FBAR uses the exchange rate on the last day of the year.
Note: Unlike T1135, FBAR uses the sum of the maxes of each account, not a single
day max across all.
EOS
}

readonly accounts=(
    "Assets:TD Checking"
    "Assets:TD Savings"
    "Assets:TD US Dollar"
)

main() {
    year=$1
    exchange=$2
    next=$(( year + 1 ))
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
        res=$(ledger reg -e "$next" "^$acct\$" \
                --date-format '%Y-%m-%d' --format "$format" \
                | jq -s "$jqexpr")
        date=$(jq -r '.date' <<< "$res")
        total=$(jq -r '.total' <<< "$res")
        value=$(jq -r '.value' <<< "$res")
        if [[ "$total" == 'USD'* ]]; then
            usd=$value
        else
            usd=$(bc <<< "scale=2; $value / $exchange")
        fi
        printf "%-20s %15s %10s %15s on %s\n" \
            "$acct" "$total" "($value)" "[USD $usd]" "$date"
        combined=$(bc <<< "scale=2; $combined + $usd")
    done
    echo "------------------------------------------------------------"
    printf "Aggregate: %15s\n" "USD $combined"
}

while getopts "h" opt; do
    case $opt in
        h) usage; exit 0;;
        *) exit 1 ;;
    esac
done
shift $((OPTIND - 1))

if [[ $# -ne 2 ]]; then
    usage
    exit 1
fi

main "$@"
