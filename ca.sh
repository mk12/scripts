#!/bin/bash

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
all_cmds='abceinps'
on_cmds='abps'
be_cmds='aceinp'

error() {
    echo "$name: $1" >&2
    exit 1
}

check_on() {
    [[ $on_cmds == *${1:0:1}* ]] || error "$1: needs begin/end dates"
}

check_be() {
    [[ $be_cmds == *${1:0:1}* ]] || error "$1: needs 'on' date"
}

if [[ $all_cmds != *${1:0:1}* ]]; then
    error "$1: invalid command"
fi

case $# in
    1)
        check_on "$1"
        ;;
    2)
        [[ $2 != 'on' ]] || error "invalid use of 'on'"
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
    if [[ $begin != "" && $end != "" ]]; then
        ledger -b "$begin" -e "$end" "$@"
    elif [[ $begin != "" ]]; then
        ledger -b "$begin" "$@"
    elif [[ $end != "" ]]; then
        ledger -e "$end" "$@"
    else
        ledger "$@"
    fi
}

summary() {
    # Get the start of the year.
    if [[ $end == "" ]]; then
        jan1='this year'
    else
        jan1=$(date -j -f '%Y/%m/%d' "$end" +'%Y' 2>/dev/null)
        if [[ $jan1 == "" ]]; then
            error "$end: summary requires YYYY/MM/DD"
        fi
    fi

    echo "NET WORTH"
    echo "========================================"
    invoke -nE bal '^Assets' '^Liabilities' || exit 1
    echo
    echo "YTD NET INCOME"
    echo "========================================"
    begin=$jan1 invoke -n --invert bal '^Expenses' '^Income' || exit 1
    echo
    echo "DUE FROM OTHERS"
    echo "========================================"
    invoke bal '^Assets:Due From' || exit 1
    echo
    echo "DUE TO OTHERS"
    echo "========================================"
    invoke --invert bal '^Liabilities:Due To' || exit 1
    echo
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
    ?) error ;;
esac
