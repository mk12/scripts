#!/bin/bash

# This script moves the contents of Today.txt to the end of Journal.txt,
# preceded by a heading of the form "# Weekday, Day Month Year".

name=$(basename "$0")
usage="usage: $name [-hfdl] [-t file] [-j file] [-v[+|-]val[ymwdHMS]]"

today=~/ia/Journal/Today.txt
journal=~/ia/Journal/Journal.txt
force=false
offset=-5H
language=false

while getopts ':t:j:n:v:hfdl' opt; do
	case $opt in
		f) force=true;;
		t) today=$OPTAG;;
		j) journal=$OPTARG;;
		v) offset=$OPTARG;;
		d) offset='-1d';;
		l) language=true;;
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

if [[ $force == true ]]; then
	[[ -f $journal ]] || touch $journal
	[[ -f $today ]] || touch $today
else
	[[ -f $journal ]] || (echo "$name: $journal: no such file" >&2; exit 1)
	[[ -f $today ]] || (echo "$name: $today: no such file" >&2; exit 1)
	[[ -s $today ]] || (echo "$name: $today: file is empty" >&2; exit 1)
fi

opts="-v $offset"
year=$(date $opts +%Y)
month=$(date $opts +%B)
weekday=$(date $opts +%A)
day=$(date $opts +%e | xargs)

entry=$'\n'
entry+="# $weekday, $day $month $year"$'\n\n'
entry+=$(< $today)
entry+=$'\n'
echo -n "$entry" >> $journal
if $language; then
	if [[ "02468" == *"${day: -1}"* ]]; then
		echo -n "English" > $today
	else
		echo -n "Français" > $today
	fi
else
	> $today
fi
