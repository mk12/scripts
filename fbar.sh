#!/bin/bash

set -eufo pipefail

usage() {
    cat <<EOS
usage: $0 [-h] YEAR

This script calculates maximum account balances for foreign (outside U.S.)
accounts during a year, for FBAR filing.
EOS
}

readonly accounts=(
    "Assets:TD Checking"
    "Assets:TD Savings"
    "Assets:TD US Dollar"
)

main() {
    year=$1
    next=$(( year + 1 ))
    ymd="$year-01-01"
    url="https://www.bankofcanada.ca/valet/observations/group/FX_RATES_ANNUAL/json?start_date=$ymd"
    echo "Fetching the average USDCAD rate for $year:"
    echo "$url"
    exchange=$(curl -s "$url" | jq -r ".observations | .[] | select(.d == \"$ymd\") | .FXAUSDCAD.v")
    echo "Using USDCAD: $exchange"
    echo
    cad=0
    usd=0
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
        printf "%-20s %15s %15s on %s\n" "$acct" "$total" "($value)" "$date"
        if [[ "$total" == 'USD'* ]]; then
            usd=$(bc <<< "scale=2; $usd + $value")
        else
            cad=$(bc <<< "scale=2; $cad + $value")
        fi
    done
    cad_in_usd=$(bc <<< "scale=2; $cad / $exchange")
    combined=$(bc <<< "scale=2; $usd + $cad_in_usd")
    echo
    printf "Total  %15s = %s\n" "CAD $cad" "USD $cad_in_usd"
    printf "Total  %15s   %s\n" "" "USD $usd"
    echo "------------------------------------------------------------"
    printf "       %15s   %s\n" "" "USD $combined"
}

while getopts "h" opt; do
    case $opt in
        -h) usage; exit 0;;
    esac
done
shift $((OPTIND - 1))

if [[ $# -ne 1 ]]; then
    usage
    exit 1
fi

main "$@"
