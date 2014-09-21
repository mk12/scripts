#!/bin/bash

# This script takes a program that reads from standard input and writes to
# standard output as its first argument. It executes the program on each of the
# files provided in the subsequent arguments, each time saving the progam output
# back to the file. This is useful for using scripts that operate only on
# streams where otherwise you would have to create a temporary file.

name=$(basename "$0")
usage="usage: $name [-h] program file ..."

if (( $# == 0 )); then
	echo "$usage" >&2
	exit 1
fi

if [[ $1 == '-h' ]]; then
	echo "$usage"
	exit 0
fi

if (( $# == 1 )); then
	echo "$usage" >&2
	exit 1
fi

prog=$1
shift
for file; do
	filename=$(basename file)
	temp=$(mktemp -t "$filename")
	if "$prog" < "$file" > "$temp"; then
		mv -f "$file" "$HOME/.vim/backup/$filename~"
		mv -f "$temp" "$file"
	else
		echo "$name: $prog failed with exit status $?"
	fi
	rm "$temp" 2> /dev/null
done
