#!/bin/bash

set -eufo pipefail

qr=false

usage() {
    cat <<EOS
usage: $0 [-hq] IDENTIFIER

Copies a TOTP code to the clipboard based on IDENTIFIER (can just be a prefix).
With -q, it produces a QR code of the secret as a PNG and opens it.
EOS
}

die() {
    echo "$0: $*" >&2
    exit 1
}

main() {
    if [[ $# -lt 1 ]]; then
        usage >&2
        exit 1
    fi
    line=$(grep -i "^$1" < ~/.totp)
    if [[ -z "$line" ]]; then
        die "$1: invalid label"
    fi
    secret=$(cut -d ' ' -f 3 <<< "$line")
    if [[ "$qr" == true ]]; then
        if ! command -v qrencode &> /dev/null; then
            die "oathtool missing; try 'brew install qrencode'"
        fi
        issuer=$(cut -d ' ' -f 1 <<< "$line")
        account=$(cut -d ' ' -f 2 <<< "$line")
        url="otpauth://totp/$issuer:$account?secret=$secret&issuer=$issuer"
        file=/tmp/qrtotp.png
        qrencode -s 10 -o "$file" "$url" || :
        open "$file" || :
        sleep 5
        rm "$file"
    else
        if ! command -v oathtool &> /dev/null; then
            die "oathtool missing; try 'brew install oath-toolkit'"
        fi
        oathtool --totp -b "$secret" | pbcopy
    fi
}

while getopts "hq" opt; do
    case $opt in
        h) usage; exit ;;
        q) qr=true ;;
        *) exit 1 ;;
    esac
done
shift $((OPTIND-1))

main "$@"
