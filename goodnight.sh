#!/bin/bash

# This script moves the contents of Today.md to the end of Journal.md. (I use
# Today.md because Journal.md is a huge file that will only get bigger, and I
# don't want to have to scroll to the bottom or deal with slow loading.) The
# entry is preceded by a heading of the form "# Weekday, Day Month Year". By
# default, the date used is the date five hours ago because I write journal
# entries past midnight sometimes but never early in the morning.

name=$(basename "$0")
usage="usage: $name [-hfd] [-t file] [-j file] [-n num] [-v[+|-]val[ymwdHMS]]"

today=~/ia/Journal/Today.md
journal=~/ia/Journal/Journal.md
force=false
tailn=0
offset=-5H

while getopts ':t:j:n:v:hfd' opt; do
	case $opt in
		f) force=true;;
		t) today=$OPTAG;;
		j) journal=$OPTARG;;
		n) tailn=$OPTARG;;
		v) offset=$OPTARG;;
		d) offset='-1d';;
		h)
			echo "$usage"
			exit 0
			;;
		:)
			echo "$name: $OPTARG: missing argument" >&2
			echo "$usage" >&2
			exit 1
			;;
		\?)
			echo "$name: $OPTARG: illegal option" >&2
			echo "$usage" >&2
			exit 1
			;;
	esac
done

if $force; then
	[[ -f $journal ]] || touch $journal
	[[ -f $today ]] || touch $today
else
	[[ -f $journal ]] || (echo "$name: $journal: no such file" >&2; exit 1)
	[[ -f $today ]] || (echo "$name: $today: no such file" >&2; exit 1)
	[[ -s $today ]] || (echo "$name: $today: file is empty" >&2; exit 1)
fi

entry=$'\n\n'
opts="-v $offset"
year=$(date $opts +%Y)
month=$(date $opts +%B)
weekday=$(date $opts +%A)
day=$(date $opts +%e | xargs)

entry+="# $weekday, $day $month $year"$'\n\n'
entry+=$(< $today)
echo -n "$entry" >> $journal
> $today
