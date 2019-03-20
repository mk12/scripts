#!/bin/bash

set -eufo pipefail

prog=$(basename "$0")

xdg_data_dir=${XDG_DATA_HOME:-$HOME/.local/share}/itermcolormap
presets_file="$xdg_data_dir/presets.txt"

update=false
map_alternates=false

say() {
    echo " * $*"
}

die() {
    echo "$prog: $*" >&2
    exit 1
}

usage() {
    cat <<EOF
usage: $prog [-hua] [THEME ...]

sets up color preset shortcuts for iTerm2

This script accepts a list of color preset names as arguments, or allows you to
interactively select them if none are provided. It produces XML to place in the
<key>GlobalKeyMap</key> section of com.googlecode.iterm2.plist that makes the
shortcuts Ctrl-Cmd-1, Ctrl-Cmd-2, etc. switch to those color presets.

options:
    -h  show this help message
    -u  regenerate the list of color preset names
    -a  map alternate (light/dark) presets to Ctrl-Alt-Cmd-(number)
EOF
}

create_preset_cache() {
    mkdir -p "$xdg_data_dir"
    if osascript <<EOF | sed '/^$/d' | sort > "$presets_file"
set iTermPList to "~/Library/Preferences/com.googlecode.iterm2.plist"
tell application "System Events"
    tell property list file iTermPList
        tell contents
            set names to name of every property list item of property list item ¬
                "Custom Color Presets"
            set output to ""
            repeat with s in names
                set output to output & s & "\n"
            end repeat
            return output
        end tell
    end tell
end tell
EOF
    then
        say "successfully updated presets"
    else
        die "failed to update presets"
    fi
}

write_one_mapping() {
    cat <<EOF
<key>0x$2-0x$1</key>
<dict>
    <key>Action</key>
    <integer>40</integer>
    <key>Text</key>
    <string>$3</string>
</dict>
EOF
}

write_mappings() {
    ctrl_cmd="140000"
    ctrl_alt_cmd="1c0000"

    n=31
    for name in "$@"; do
        write_one_mapping "$ctrl_cmd" "$n" "$name"
        ((n++))
    done

    if [[ "$map_alternates" == true ]]; then
        n=31
        for name in "$@"; do
            alternate=$name
            for possibility in \
                    "$name-light" \
                    "$name-dark" \
                    "$name-night" \
                    "${name%-light}" \
                    "${name%-dark}" \
                    "${name%-night}" \
                    "${name%dark}light" \
                    "${name%-dark}light" \
                    "${name%dark}-light" \
                    "${name%light}dark" \
                    "${name%-light}dark" \
                    "${name%light}-dark"; do
                if [[ "$name" != "$possibility" ]] && \
                        grep -q "^$possibility$" "$presets_file"; then
                    alternate=$possibility
                    break
                fi
            done
            write_one_mapping "$ctrl_alt_cmd" "$n" "$alternate"
            ((n++))
        done
    fi
}

main() {
    if [[ "$update" == true ]]; then
        create_preset_cache
        return
    fi

    if ! [[ -f "$presets_file" ]]; then
        die "preset cache does not exist (try running $prog -u)"
    fi

    if [[ $# -gt 0 ]]; then
        write_mappings "$@"
    else
        presets=()
        while read -r name; do
            presets+=("$name")
        done < <(fzf -m < "$presets_file")
        write_mappings "${presets[@]+"${presets[@]}"}"
    fi
}

while getopts "hua" opt; do
    case $opt in
        h) usage; exit 0 ;;
        u) update=true ;;
        a) map_alternates=true ;;
        *) exit 1 ;;
    esac
done
shift $((OPTIND - 1))

main "$@"
