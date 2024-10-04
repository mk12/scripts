#!/bin/bash

set -eufo pipefail

usage() {
    cat <<EOS
Usage: $0 WORD

Lookup IPA transcriptions of WORD
EOS
}

if [[ $# -ne 1 || "$1" = -* ]]; then
    usage >&2
    exit 1
fi

word=$1

get() {
    case $1 in
        dictionary.com)
            curl -s "https://www.$1/browse/$word" \
            | rg '\\"pronunciations\\":\[\{\\"ipa\\":\\"(.*?)\\"' -r '$1' -o
            ;;
        tophonetics.com)
            curl -s "https://$1" \
                --data-urlencode text_to_transcribe="$word" \
                --data-urlencode output_dialect=am \
                --data-urlencode output_style=only_tr \
                --data-urlencode submit="Show transcription" \
            | htmlq --text '#transcr_output'
            ;;
        merriam-webster.com)
            curl -s "https://www.$1/dictionary/$word" \
            | htmlq --text 'a[title^="How to pronounce"]'
            ;;
    esac
}

normalize() {
    # shellcheck disable=SC2016
    ipa=$(head -n 1 | sd '^\s*/?\s*(.*?)\s*/?\s*$' '$1')
    case $ipa in
        *"ˈ"*) echo "/$ipa/" ;;
        *) echo "/ˈ$ipa/" ;;
    esac
}

update() {
    delta=$((total + 1 - $1))
    # shellcheck disable=SC2059
    printf "\x1b[${delta}A\r\x1b[2K${2}\x1b[${delta}B\r"
}

monitor() {
    update "$1" "$2:"
    update "$1" "$2: $(get "$2" | normalize)"
}

print_newlines() {
    head -c "$1" /dev/zero | tr '\0' $'\n'
}

total=3
print_newlines $total

monitor 1 dictionary.com &
monitor 2 merriam-webster.com &
monitor 3 tophonetics.com &

wait
