#!/bin/bash

# This script hides the file extensions (in the Finder) of all the files in the
# given directory.

name=$(basename "$0")
usage="usage: $name [-h] directory ..."

if (( $# == 0 )); then
    echo "$usage" >&2
    exit 1
fi

if [[ $1 == '-h' ]]; then
    echo "$usage"
    exit 0
fi

remove_extensions() {
    while read i; do
        SetFile -a E "$i"
    done
}

if [[ $1 == '-' ]]; then
    remove_extensions
else
    find "$@" -type f | remove_extensions
fi
