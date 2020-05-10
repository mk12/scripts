#!/bin/bash

set -eufo pipefail

# Script for generating reports with ledger.

name=$(basename "$0")
usage="usage: $name COMMAND [on DATE | BEGIN [END]]

  Cmd  Name              On  Begin/End
  ---  ----------------  --  ---------
  a    Accounts          X   X
  b    Balance sheet     X
  c    Cash flow             X
  e    Expense report        X
  i    Income report         X
  n    Net income            X
  p    Payees            X   X
  s    Summary           X
  v    Investments       X   X
  4    401k info         X
"

if (( $# < 1 || $# > 3 )); then
    echo "$usage"
    exit 0
fi

if [[ $1 == '-h' || $1 == '--help' ]]; then
    echo "$usage"
    exit 0
fi

# 'ON' commands report based on a moment in time.
# 'BE' commands report based on a Begin/End time interval.
all_cmds='abceinpsv4'
on_cmds='abpsv4'
be_cmds='aceinpv'

error() {
    echo "$name: $1" >&2
    exit 1
}

check_on() {
    if ! [[ $on_cmds == *${1:0:1}* ]]; then
        error "$1: needs begin/end dates"
    fi
}

check_be() {
    if ! [[ $be_cmds == *${1:0:1}* ]]; then
        error "$1: needs 'on' date"
    fi
}

if [[ $all_cmds != *${1:0:1}* ]]; then
    error "$1: invalid command"
fi

begin=
end=
jan1=

case $# in
    1)
        check_on "$1"
        ;;
    2)
        if ! [[ $2 != 'on' ]]; then
            error "invalid use of 'on'"
        fi
        check_be "$1"
        begin=$2
        ;;
    3)
        if [[ $2 == 'on' ]]; then
            check_on "$1"
            end=$3
        else
            check_be "$1"
            begin=$2
            end=$3
        fi
        ;;
esac

invoke() {
    if [[ -n $begin && -n $end ]]; then
        ledger -b "$begin" -e "$end" "$@"
    elif [[ -n $begin ]]; then
        ledger -b "$begin" "$@"
    elif [[ -n $end ]]; then
        ledger -e "$end" "$@"
    else
        ledger "$@"
    fi
}

get_jan1() {
    # Get the start of the year.
    if [[ $end == "" ]]; then
        jan1='this year'
    else
        jan1=$(date -j -f '%Y/%m/%d' "$end" +'%Y' 2>/dev/null)
        if [[ $jan1 == "" ]]; then
            error "$end: summary requires YYYY/MM/DD"
        fi
    fi
}

summary() {
    get_jan1

    echo "NET WORTH"
    echo "========================================"
    invoke -nE bal '^Assets' '^Liabilities' -X USD
    echo
    echo "YTD NET INCOME"
    echo "========================================"
    begin=$jan1 invoke -n --invert bal '^Expenses' '^Income'
    echo
    echo "DUE FROM OTHERS"
    echo "========================================"
    invoke bal '^Assets:Due From'
    echo
    echo "DUE TO OTHERS"
    echo "========================================"
    invoke --invert bal '^Liabilities:Due To'
}

investments() {
    if [[ -z "$begin" ]]; then
        echo "INVESTMENTS"
        echo "========================================"
        invoke bal '^Assets:Vanguard' -X USD
    fi
    echo
    echo "REALIZED GAINS"
    echo "========================================"
    invoke bal '^Income:Capital Gains' -X USD --invert
    echo
    echo "REALIZED LOSSES"
    echo "========================================"
    invoke bal '^Expenses:Capital Losses' -X USD
    if [[ -z "$begin" ]]; then
        # In theory you could report unrealized gains/losses over a span of
        # time, but I can't figure out how to do that properly in ledger.
        echo
        echo "UNREALIZED GAINS/LOSSES"
        echo "========================================"
        invoke bal '^Assets:Vanguard' -G -X USD
    fi
    echo
    echo "DIVIDENDS"
    echo "========================================"
    invoke bal '^Income:Dividends' -X USD --invert
}

info_401k() {
    get_jan1

    echo "YTD PRE-TAX SELF"
    echo "========================================"
    begin=$jan1 invoke bal "Assets:Vanguard 401k Pretax" \
        and not @Vanguard and not note '401k match' -X USD -B
    echo
    echo "YTD PRE-TAX EMPLOYER"
    echo "========================================"
    begin=$jan1 invoke bal "Assets:Vanguard 401k Pretax" \
        and not @Vanguard and note '401k match' -X USD -B
    echo
    echo "YTD TOTAL 401K"
    echo "========================================"
    begin=$jan1 invoke bal "Assets:Vanguard 401k" \
        and not @Vanguard -X USD -B
}

case ${1:0:1} in
    a) invoke -E accounts ;;
    b) invoke bal '^Assets' '^Liabilities' ;;
    c) invoke bal '^Assets' ;;
    e) invoke bal '^Expenses' ;;
    i) invoke --invert bal '^Income' ;;
    n) invoke --invert --depth 2 bal '^Income' '^Expenses' ;;
    p) invoke payees ;;
    s) summary ;;
    v) investments ;;
    4) info_401k ;;
    ?) error ;;
esac
