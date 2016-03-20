#!/bin/bash

# Script for generating reports with ledger.

name=$(basename "$0")
usage="usage: $name COMMAND [on DATE | BEGIN [END]]

  Cmd  Name              On  Interval
  ---  ----------------  --  --------
  a    Accounts          X   X
  b    Balance sheet     X
  c    Cash flow             X
  e    Expense report        X
  i    Income report         X
  n    Net income            X
  p    Payees            X   X
  s    Summary
"

if (( $# < 1 || $# > 3 )); then
	echo "$usage"
	exit 0
fi

if [[ $1 == '-h' || $1 == '--help' ]]; then
	echo "$usage"
	exit 0
fi

error() {
	echo "$name: $1" >&2
	exit 1
}

if [[ 'abceinps' != *${1:0:1}* ]]; then
	error "$1: invalid command"
fi

case $# in
	1)
		[[ 'abps' == *${1:0:1}* ]] || error "$1: needs date interval"
		;;
	2)
		[[ $2 != 'on' ]] || error "invalid use of 'on'"
		[[ 'aceinp' == *${1:0:1}* ]] || error "$1: needs 'on' date"
		begin=$2
		;;
	3)
		if [[ $2 == 'on' ]]; then
			[[ 'abp' == *${1:0:1}* ]] || error "$1: needs date interval"
			end=$3
		else
			[[ 'aceinp' == *${1:0:1}* ]] || error "$1: needs 'on' date"
			begin=$2
			end=$3
		fi
		;;
esac

summary() {
	echo "NET WORTH"
	echo "========================================"
	ledger -nE bal '^Assets' '^Liabilities'
	echo
	echo "NET INCOME (past month)"
	echo "========================================"
	ledger -b 'last month' -n --invert bal '^Expenses' '^Income'
	echo
	echo "DEBTS TO COLLECT"
	echo "========================================"
	ledger bal '^Assets:Due From'
	echo
	echo "DEBTS TO PAY"
	echo "========================================"
	ledger --invert bal '^Liabilities:Due To'
	echo
}

case ${1:0:1} in
	a) opts="-E accounts" ;;
	b) opts="bal '^Assets' '^Liabilities'" ;;
	c) opts="bal '^Assets'" ;;
	e) opts="bal '^Expenses'" ;;
	i) opts="--invert bal '^Income'" ;;
	n) opts="--invert --depth 2 bal '^Income' '^Expenses'" ;;
	p) opts="payees" ;;
	s) summary; exit 0 ;;
	?) error ;;
esac

if [[ $begin != "" && $end != "" ]]; then
	ledger -b "$begin" -e "$end" $opts
elif [[ $begin != "" ]]; then
	ledger -b "$begin" $opts
elif [[ $end != "" ]]; then
	ledger -e "$end" $opts
else
	ledger $opts
fi
