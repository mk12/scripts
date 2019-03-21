#!/bin/bash

set -eufo pipefail

prog=$(basename "$0")

xdg_data_dir=${XDG_DATA_HOME:-$HOME/.local/share}/itermcolormap
all_presets_file="$xdg_data_dir/presets.txt"
xdg_config_dir=${XDG_CONFIG_HOME:-$HOME/.config}/itermcolormap
my_presets_file="$xdg_config_dir/default.txt"

bin_plist="$HOME/Library/Preferences/com.googlecode.iterm2.plist"
plist="$PROJECTS/dotfiles/iterm2/com.googlecode.iterm2.plist"
keymap="GlobalKeyMap"

indent=

update=false
just_list=false
map_alternates=false
in_place=false

say() {
    echo " * $*"
}

die() {
    echo "$prog: $*" >&2
    exit 1
}

usage() {
    cat <<EOF
usage: $prog [-ahilu] [THEME ...]

sets up color preset shortcuts for iTerm2

This script accepts a list of color preset names as arguments. It produces XML
to place in the <key>GlobalKeyMap</key> section of com.googlecode.iterm2.plist
that makes the shortcuts Ctrl-Cmd-1, Ctrl-Cmd-2, etc. switch to those color
presets. If called without arguments, it looks for arguments in the config file.

config file:
    $my_presets_file

options:
    -a  map alternate (light/dark) presets to Ctrl-Alt-Cmd-(number)
    -h  show this help message
    -i  edit the plist in place instead of dumping XML
    -l  list the available presets
    -u  regenerate the list of color preset names
EOF
}

create_preset_cache() {
    mkdir -p "$xdg_data_dir"
    if osascript <<EOF | sed '/^$/d' | sort > "$all_presets_file"
set iTermPList to "$bin_plist"
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
$indent<key>0x$2-0x$1</key>
$indent<dict>
$indent    <key>Action</key>
$indent    <integer>40</integer>
$indent    <key>Text</key>
$indent    <string>$3</string>
$indent</dict>
EOF
}

write_mappings() {
    ctrl_cmd="140000"
    ctrl_alt_cmd="1c0000"

    n=31
    for name in "$@"; do
        write_one_mapping "$ctrl_cmd" "$n" "$name"
        ((n++))
        if [[ "$n" -eq 40 ]]; then
            n=30
        fi
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
                    "${name/dark/light}" \
                    "${name%-dark}light" \
                    "${name%dark}-light" \
                    "${name/dark/light}" \
                    "${name%-light}dark" \
                    "${name%light}-dark"; do
                if [[ "$name" != "$possibility" ]] && \
                        grep -q "^$possibility$" "$all_presets_file"; then
                    alternate=$possibility
                    break
                fi
            done
            write_one_mapping "$ctrl_alt_cmd" "$n" "$alternate"
            ((n++))
            if [[ "$n" -eq 40 ]]; then
                n=30
            fi
        done
    fi
}

main() {
    if [[ "$update" == true ]]; then
        create_preset_cache
        return
    fi
    if ! [[ -f "$all_presets_file" ]]; then
        die "preset cache does not exist (try running $prog -u)"
    fi
    if [[ "$just_list" == true ]]; then
        cat "$all_presets_file"
        return
    fi

    presets=("$@")
    if [[ "${#presets[@]}" -eq 0 ]]; then
        die "zero presets provided!"
    fi
    if [[ "${#presets[@]}" -gt 10 ]]; then
        die "too many presets provided (max is 10)"
    fi

    if [[ "$in_place" == true ]]; then
        indent=$'\t\t'
        if ! grep -q "<key>$keymap</key>" "$plist"; then
            die "$plist: does not contain $keymap"
        fi
        out=$(mktemp)
        sed -ne "1,/<key>$keymap<\\/key>/p" < "$plist" > "$out"
        printf "\t%s\n" "<dict>" >> "$out"
        write_mappings "${presets[@]+"${presets[@]}"}" >> "$out"
        buf=
        mode=0
        linecount=0
        while IFS="" read -r line || [[ -n "$line" ]]; do
            ((++linecount))
            if [[ "$linecount" -le 2 ]]; then
                continue
            fi
            buf+="$line"
            buf+=$'\n'
            advance=false
            case $mode in
                0) [[ "$line" == *"<key>0x3"* ]] && advance=true ;;
                1) [[ "$line" == *"<dict>"* ]] && advance=true ;;
                2) [[ "$line" == *"<key>Action"* ]] && advance=true ;;
                3) [[ "$line" == *"<integer>40"* ]] && advance=true ;;
                4) [[ "$line" == *"<key>Text"* ]] && advance=true ;;
                5) [[ "$line" == *"<string>"* ]] && advance=true ;;
                6) [[ "$line" == *"</dict>"* ]] && advance=true ;;
            esac
            if [[ "$advance" == true ]]; then
                ((mode++))
                if [[ "$mode" -eq 7 ]]; then
                    buf=
                    mode=0
                fi
            else
                printf "%s" "$buf" >> "$out"
                buf=
                mode=0
            fi
        done < <(sed -ne \
            "/<key>$keymap<\\/key>/,/^"$'\t'"<\\/dict>/p" < "$plist")
        sed -e "1,/<key>$keymap<\\/key>/d" < "$plist" \
            | sed -e "1,/^"$'\t'"<\\/dict>/d" >> "$out"
        mv -f "$out" "$plist"
        say "successfully edited $plist"
    else
        write_mappings "${presets[@]+"${presets[@]}"}"
    fi
}

if [[ $# -eq 0 ]]; then
    say "looking for config in $my_presets_file"
    if ! [[ -f "$my_presets_file" ]]; then
        die "$my_presets_file: file not found"
    fi
    while read -r line; do
        set -- "$@" "$line"
    done < "$my_presets_file"
fi

while getopts "ahilu" opt; do
    case $opt in
        a) map_alternates=true ;;
        h) usage; exit 0 ;;
        i) in_place=true ;;
        l) just_list=true ;;
        u) update=true ;;
        *) exit 1 ;;
    esac
done
shift $((OPTIND - 1))

main "$@"
