#!/bin/bash

set -eufo pipefail

readonly w=12

ansi_fg() {
    if [[ "$1" -lt 8 ]]; then
        echo $(( 30 + $1 ))
    elif [[ "$1" -lt 16 ]]; then
        echo $(( 90 + $1 - 8 ))
    else
        echo "38;5;$1"
    fi
}

ansi_bg() {
    if [[ "$1" -lt 8 ]]; then
        echo $(( 40 + $1 ))
    elif [[ "$1" -lt 16 ]]; then
        echo $(( 100 + $1 - 8 ))
    else
        echo "48;5;$1"
    fi
}

show() {
    b16_hex=$1
    shift
    fg_fg=$(ansi_fg "$2")
    fg_bg=
    [[ $# -ge 3 ]] && fg_bg=";$(ansi_bg "$3")"
    bg_bg=$(ansi_bg "$2")
    bg_fg=
    [[ $# -ge 4 ]] && bg_fg=";$(ansi_fg "$4")"

    printf "\x1b[90m(%02d:%s)\x1b[0m " "$2" "$b16_hex"
    printf "\x1b[${fg_fg}${fg_bg}m %-${w}s \x1b[0m  " "$1"
    printf "\x1b[${bg_bg}${bg_fg}m %-${w}s \x1b[0m" "$1"
}

gap() {
    printf "    "
}

show "0" "background" 0 18 7; gap; show "3" "comment"     8 0 0; gap; show "9" "directive" 16 0 0; echo
show "8" "error/-"    1 0 0 ; gap; show "8" "error/-"     9 0 0; gap; show "f" "special"   17 0 0; echo
show "b" "keyword/+"  2 0 0 ; gap; show "b" "keyword/+"  10 0 0; gap; show "1" "highlight" 18 0 7; echo
show "a" "identifier" 3 0 0 ; gap; show "a" "identifier" 11 0 0; gap; show "2" "selection" 19 0 7; echo
show "d" "function"   4 0 0 ; gap; show "d" "function"   12 0 0; gap; show "4" "subtle"    20 0 0; echo
show "e" "type/other" 5 0 0 ; gap; show "e" "type/other" 13 0 0; gap; show "6" "emphasis"  21 0 0; echo
show "c" "constant"   6 0 0 ; gap; show "c" "constant"   14 0 0; gap; echo
show "5" "foreground" 7 0 0 ; gap; show "7" "inverse bg" 15 0 0; gap; echo
