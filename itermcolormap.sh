#!/bin/bash

set -eufo pipefail

prog=$(basename "$0")

xdg_data_dir=${XDG_DATA_HOME:-$HOME/.local/share}/itermcolormap
all_presets_file="$xdg_data_dir/presets"
current_preset_file="$xdg_data_dir/current"
xdg_config_dir=${XDG_CONFIG_HOME:-$HOME/.config}/itermcolormap
fav_presets_file="$xdg_config_dir/fav.txt"
fav_presets=()

bin_plist="$HOME/Library/Preferences/com.googlecode.iterm2.plist"
plist="$PROJECTS/dotfiles/iterm2/com.googlecode.iterm2.plist"
keymap="GlobalKeyMap"

# Ctrl+Cmd
fav_modifier="140000"

# Used for indenting the XML.
indent=

# Command-line options.
opt_alternate=false
opt_dump=false
opt_interactive=false
opt_list=false
opt_list_fav=false
opt_patch=false
opt_update=false

say() {
    echo " * $*"
}

die() {
    echo "$prog: $*" >&2
    exit 1
}

usage() {
    cat <<EOF
usage: $prog [-adfhilnpu] [THEME]

sets up color preset shortcuts for iTerm2

options:
    -a  switch to alternate (dark/light) preset
    -d  dump the XML prefs
    -f  list your favorite presets
    -h  show this help message
    -i  interactive mode
    -l  list the available presets
    -p  patch prefs in the dotfiles repo
    -u  regenerate the list of color presets
EOF
}

create_preset_cache() {
    mkdir -p "$xdg_data_dir"
    if ! osascript <<EOF | sed '/^$/d' | sort > "$all_presets_file"
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
        die "failed to update presets"
    fi
    say "successfully updated presets"
}

load_fav_presets() {
    if ! [[ -f "$fav_presets_file" ]]; then
        die "$fav_presets_file: file not found"
    fi
    while read -r line; do
        fav_presets+=("$line")
    done < "$fav_presets_file"

    if [[ "${#fav_presets[@]}" -gt 10 ]]; then
        die "too many favorite presets provided (max is 10)"
    fi
}

get_alternate() {
    for preset in "$1-light" "$1-dark" "$1-night" \
            "${1%-light}" "${1%-dark}" "${1%-night}" \
            "${1/dark/light}" "${1/light/dark}" \
            "${1%-dark}light" "${1%dark}-light" \
            "${1%-light}dark" "${1%light}-dark"; do
        if [[ "$1" != "$preset" ]] && \
                grep -q "^$preset$" "$all_presets_file"; then
            echo "$preset"
            return
        fi
    done
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
    n=31
    for name in "${fav_presets[@]+"${fav_presets[@]}"}"; do
        write_one_mapping "$fav_modifier" "$n" "$name"
        ((n++))
        if [[ "$n" -eq 40 ]]; then
            n=30
        fi
    done
}

modify_plist() {
    indent=$'\t\t'
    if ! grep -q "<key>$keymap</key>" "$plist"; then
        die "$plist: does not contain $keymap"
    fi
    out=$(mktemp)
    sed -ne "1,/<key>$keymap<\\/key>/p" < "$plist" > "$out"
    printf "\t%s\n" "<dict>" >> "$out"
    write_mappings >> "$out"
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
            0) [[ "$line" == *"<key>0x"* ]] && advance=true ;;
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
}

set_preset() {
    if ! grep -q "^$1$" "$all_presets_file"; then
        die "$1: unknown color preset"
    fi
    esc="\x1b]1337;SetColors=preset=$1\x07"
    if [[ -n "${TMUX+x}" ]]; then
        esc="\x1bPtmux;\x1b$esc\x1b\\"
    fi
    printf "$esc"
    echo "$1" > "$current_preset_file"
}

interactive_mode() {
    cat <<EOF
j  next
k  previous
a  alternate (light/dark)
f  fzf preset(s)
r  reset filter
q  quit

EOF

    preset=$(< "$current_preset_file")
    if [[ -z "$preset" ]]; then
        preset=$(head -n1 "$all_presets_file")
    fi
    has_filter=false
    filtered=$(mktemp)
    cp "$all_presets_file" "$filtered"
    echo "preset:"

    while true; do
        read -rn 1 char
        printf "\r\x1b[2K"
        new=
        case $char in
            j)
                new=$(sed -ne "/^$preset\$/,\$p" < "$filtered" \
                    | sed '2q;d')
                if [[ -z "$new" ]]; then
                    new=$(head -n1 "$filtered")
                fi
                ;;
            k)
                new=$(sed "/^$preset\$/,\$d" < "$filtered" | tail -n1)
                if [[ -z "$new" ]]; then
                    new=$(tail -n1 "$filtered")
                fi
                ;;
            a)
                new=$(get_alternate "$preset")
                cp "$all_presets_file" "$filtered"
                has_filter=false
                ;;
            f)
                nothing=false
                fzf -m --bind=tab:toggle-all < "$all_presets_file" \
                    > "$filtered" || nothing=true
                lines=$(wc -l "$filtered" | awk '{print $1}')
                if [[ "$nothing" == true || "$lines" -eq 0 ]]; then
                    cp "$all_presets_file" "$filtered"
                    has_filter=false
                elif [[ "$lines" -eq 1 ]]; then
                    new=$(< "$filtered")
                    cp "$all_presets_file" "$filtered"
                    has_filter=false
                else
                    new=$(head -n1 "$filtered")
                    has_filter=true
                fi
                ;;
            r)
                cp "$all_presets_file" "$filtered"
                has_filter=false
                ;;
            q) break ;;
            *) ;;
        esac
        if [[ -n "$new" && "$new" != "$preset" ]]; then
            preset=$new
            set_preset "$preset"
        fi
        if [[ "$has_filter" == true ]]; then
            filter_msg="[filtered] "
        else
            filter_msg=
        fi
        printf "\x1b[1A\r\x1b[2K%spreset: %s\n" "$filter_msg" "$preset"
    done
    rm "$filtered"
}

main() {
    if [[ "$opt_update" == true ]]; then
        create_preset_cache
        return
    fi
    if ! [[ -f "$all_presets_file" ]]; then
        die "preset cache does not exist (try running $prog -u)"
    fi
    if [[ "$opt_list" == true ]]; then
        cat "$all_presets_file"
        return
    fi
    if [[ "$opt_list_fav" == true ]]; then
        cat "$fav_presets_file"
        return
    fi

    if [[ "$opt_dump" == true ]]; then
        load_fav_presets
        write_mappings
    elif [[ "$opt_patch" == true ]]; then
        load_fav_presets
        modify_plist
    elif [[ "$opt_alternate" == true ]]; then
        if ! [[ -s "$current_preset_file" ]]; then
            die "current preset unknown"
        fi
        preset=$(< "$current_preset_file")
        alt=$(get_alternate "$preset")
        if [[ -z "$alt" ]]; then
            die "$preset: no alternate"
        fi
        set_preset "$alt"
    elif [[ "$opt_interactive" == true ]]; then
        interactive_mode
    else
        if [[ "$#" -eq 1 ]]; then
            preset=$1
        else
            preset=$(fzf < "$all_presets_file")
            if [[ -z "$preset" ]]; then
                exit 1
            fi
        fi
        set_preset "$preset"
    fi
}

while getopts "adfhilpu" opt; do
    case $opt in
        a) opt_alternate=true ;;
        d) opt_dump=true ;;
        f) opt_list_fav=true ;;
        h) usage; exit 0 ;;
        i) opt_interactive=true ;;
        l) opt_list=true ;;
        p) opt_patch=true ;;
        u) opt_update=true ;;
        *) exit 1 ;;
    esac
done
shift $((OPTIND - 1))
if [[ "$#" -gt 1 ]]; then
    die "too many arguments"
fi

main "$@"
