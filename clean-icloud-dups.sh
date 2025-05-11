#!/bin/bash

set -eufo pipefail

echo >&2 "This is obsolete since I don't use iCloud Drive anymore"
exit 1

cd "$OBSIDIAN_VAULT"

run() {
    echo "> $*"
    "$@"
}

ask() {
    read -p "$* [y/N] " -r reply < /dev/tty
    case $reply in
        y|Y) ;;
        *) return 1 ;;
    esac
}

go() {
    while read -r f; do
        base=${f%.*}
        ext=${f##*.}
        num=${base: -1}
        if [[ "$num" == 2 ]]; then
            prev_base=${base% 2}
        else
            prev_base="${base%" $num"} $((num - 1))"
        fi
        prev=$prev_base.$ext
        [[ ! -f "$prev" ]] && continue
        clear
        run bat --paging=never "$f"
        echo
        read -r -p "Press enter for diff ..." < /dev/tty
        clear
        run git diff --no-index "$prev" "$f" || :
        echo
        if ask "Remove $f?"; then
            run trash "$f"
        fi
    done < <(fd ' \d(.\w+)$' "$1")
}

go .obsidian
go .trash
go .
