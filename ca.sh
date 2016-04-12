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
  x    Exchange gain         X
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
all_cmds='abceinpsx'
on_cmds='abps'
be_cmds='aceinpx'

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
		check_on $1
		;;
	2)
		[[ $2 != 'on' ]] || error "invalid use of 'on'"
		check_be $1
		begin=$2
		;;
	3)
		if [[ $2 == 'on' ]]; then
			check_on $1
			end=$3
		else
			check_be $1
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

exchange() {
	echo "CURRENCY EXCHANGE"
	echo "========================================"
	invoke --invert bal '^Exchange' || exit 1
	echo
	# Get the end date.
	if [[ $end == "" ]]; then
		rate_date='latest'
	else
		rate_date=$(date -j -f '%Y/%m/%d' "$end" +'%Y-%m-%d' 2>/dev/null)
		if [[ $rate_date == "" ]]; then
			error "$end: exchange requires YYYY/MM/DD"
		fi
	fi
	# Download and parse the CAD/USD exchange rate.
	fixer="http://api.fixer.io/$rate_date?base=USD&symbols=CAD"
	rate=$(curl -sS "$fixer" | grep -o '"CAD":[.0-9]\+' | cut -c 7-) || exit 1
	# Invoke ledger with a simplified output format.
	output=$(invoke --invert --format='%(T)' bal '^Exchange') || exit 1
	# Extract CAD and USD from the Exchange account balance.
	if [[ ${output:0:1} == '$' ]]; then
		cad=$(echo "$output" | head -n 1 | cut -c 2-)
		usd=$(echo "$output" | sed -n '2p' | cut -c 5-)
		if [[ $usd == "" ]]; then
			usd='0.00'
		fi
	elif [[ ${output:0:3} == 'USD' ]]; then
		usd=$(echo "$output" | head -n 1 | cut -c 5-)
		cad=$(echo "$output" | sed -n '2p' | cut -c 2-)
		if [[ $cad == "" ]]; then
			cad='0.00'
		fi
	else
		# No exchange activity during this period.
		exit 0
	fi
	# Remove any commas.
	cad=${cad//,}
	usd=${usd//,}
	# Calculate the gain in terms of both currencies.
	fmt='-\?[0-9]\+\.[0-9][0-9]'
	cad_expr="$cad + ($usd * $rate)"
	usd_expr="($cad / $rate) + $usd"
	gain_cad=$(echo "$cad_expr" | bc -l | grep -o -- "$fmt") || exit 1
	gain_usd=$(echo "$usd_expr" | bc -l | grep -o -- "$fmt") || exit 1
	echo "NET EXCHANGE GAIN"
	echo "========================================"
	if [[ $rate_date == 'latest' ]]; then
		echo "Using today's exchange rate:"
	else
		echo "Using the exchange rates of $(echo $rate_date | tr '-' '/'):"
	fi
	echo "\$$gain_cad (USD $gain_usd)"
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
	x) exchange ;;
	?) error ;;
esac
