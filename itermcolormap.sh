#!/bin/bash

set -eufo pipefail

prog=$(basename "$0")

xdg_data_dir=${XDG_DATA_HOME:-$HOME/.local/share}/itermcolormap
all_presets_file="$xdg_data_dir/presets.csv"
current_preset_file="$xdg_data_dir/current"
xdg_config_dir=${XDG_CONFIG_HOME:-$HOME/.config}/itermcolormap
fav_presets_file="$xdg_config_dir/fav.txt"
fav_presets=()

bin_plist="$HOME/Library/Preferences/com.googlecode.iterm2.plist"
plist="$PROJECTS/dotfiles/iterm2/com.googlecode.iterm2.plist"
keymap="GlobalKeyMap"

fav_modifier="140000"
modifiers=(
"100000" # cmd
"120000" # shift_cmd
"140000" # ctrl_cmd
"160000" # ctrl_shift_cmd
"180000" # alt_cmd
"1a0000" # alt_shift_cmd
"1c0000" # ctrl_alt_cmd
"60000"  # ctrl_shift
"a0000"  # alt_shift
"c0000"  # ctrl_alt
"e0000"  # ctrl_alt_shift
"20000"  # shift
)

modifiers_osa=(
"command;"                # cmd
"shift:command;"          # shift_cmd
"control:command;"        # ctrl_cmd
"control:shift:command;"  # ctrl_shift_cmd
"option:command;"         # alt_cmd
"option:shift:command;"   # alt_shift_cmd
"control:option:command;" # ctrl_alt_cmd
"control:shift;"          # ctrl_shift
"option:shift;"           # alt_shift
"control:option;"         # ctrl_alt
"control:option:shift;"   # ctrl_alt_shift
"shift;"                  # shift
)

fn_keys=(
"f704" # F1
"f705" # F2 
"f706" # F3
"f707" # F4
"f708" # F5
"f709" # F6
"f70a" # F7
"f70b" # F8
"f70c" # F9
"f70d" # F10
"f70e" # F11
"f70f" # F12
)

# Applescript key codes make no sense.
fn_keys_osa=(
"122" # F1
"120" # F2 
"99" # F3
"118" # F4
"96" # F5
"97" # F6
"98" # F7
"100" # F8
"101" # F9
"109" # F10
"103" # F11
"111" # F12
)

# Used for indenting the XML.
indent=

# Command-line options.
opt_alternate=false
opt_dump=false
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
usage: $prog [-adfhlpu] [THEME]

sets up color preset shortcuts for iTerm2

options:
    -a  switch to alternate (dark/light) preset
    -d  dump the XML prefs
    -f  list your favorite presets
    -h  show this help message
    -l  list the available presets
    -p  patch prefs in the dotfiles repo
    -u  regenerate the list of color presets
EOF
}

create_preset_cache() {
    mkdir -p "$xdg_data_dir"
    tmp=$(mktemp)
    if ! osascript <<EOF | sed '/^$/d' | sort > "$tmp"
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

    m=0
    f=0
    > "$all_presets_file"
    while read -r name; do
        printf "%s,%s,%s,%s,%s\n" \
            "$name" "${modifiers[$m]}" "${fn_keys[$f]}" \
            "${modifiers_osa[$m]}" "${fn_keys_osa[$f]}" \
            >> "$all_presets_file"
        ((f++))
        if [[ "$f" -ge "${#fn_keys[@]}" ]]; then
            f=0
            ((m++))
            if [[ "$m" -ge "${#modifiers[@]}" ]]; then
                die "not enough key combinations"
            fi
        fi
    done < "$tmp"
    rm "$tmp"
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
                grep -q "^$preset," "$all_presets_file"; then
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

    while IFS=',' read -ra fields; do
        name=${fields[0]}
        mod=${fields[1]}
        fn_key=${fields[2]}
        write_one_mapping "$mod" "$fn_key" "$name"
    done < "$all_presets_file"
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
    IFS=',' read -ra fields < <(grep "^$1," "$all_presets_file") \
        || die "$1: unknown color preset"
    if [[ ${#fields[@]} -lt 1 || -z ${fields[0]} ]]; then
        die "$1: unknown color preset"
    fi
    mods=${fields[3]}
    keycode=${fields[4]}
    mods=$(sed 's/:/ down, /g;s/;/ down/' <<< "$mods")
    osascript <<EOF
tell application "System Events" to key code $keycode using {$mods}
EOF
    echo "$1" > "$current_preset_file"
    say "set color preset to $1"
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
        cut -d, -f1 "$all_presets_file"
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
    else
        if [[ "$#" -eq 1 ]]; then
            preset=$1
        else
            preset=$(cut -d, -f1 "$all_presets_file" | fzf)
            if [[ -z "$preset" ]]; then
                exit 1
            fi
        fi
        set_preset "$preset"
    fi
}

while getopts "adfhlpu" opt; do
    case $opt in
        a) opt_alternate=true ;;
        d) opt_dump=true ;;
        f) opt_list_fav=true ;;
        h) usage; exit 0 ;;
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
