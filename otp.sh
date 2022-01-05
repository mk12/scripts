#!/bin/bash

set -eufo pipefail

# Options
qr=false
decode=

# Globals
tmpdir=
issuer=
account=
secret=

readonly otp_file=~/.otp

usage() {
    cat <<EOS
usage: $0 [-q | -q IDENTIFIER] [-d IMAGE]

Copies a TOTP or HOTP code to the clipboard based on IDENTIFIER.
With -q, it produces a QR code of the secret as a PNG and opens it.
With -q and no IDENTIFIER, produces a collage of QR codes for all secrets.
With -d, decodes the QR code IMAGE and prints it.
EOS
}

die() {
    echo "$0: $*" >&2
    exit 1
}

need() {
    if ! command -v "$1" &> /dev/null; then
        die "$1 missing; try 'brew install ${2:-$1}'"
    fi
}

make_tmpdir() {
    tmpdir="$(mktemp -d)"
    trap 'rm -rf -- "$tmpdir"' EXIT
}

parse_line() {
    issuer=${1%% *}
    rest=${1#* }
    account=${rest%% *}
    rest=${rest#* }
    secret=${rest%% *}
    rest=${rest#* }
    counter=${rest#\#}
    if [[ "$counter" = "$secret" ]]; then
        counter=
    fi
}

copy_code() {
    need oathtool oath-toolkit
    if [[ -z "$counter" ]]; then
        oathtool --totp -b "$secret" | pbcopy
    else
        need trash
        oathtool --hotp -b "$secret" -c "$counter" | pbcopy
        new=$((counter + 1)) || :
        sed -i.bak "s/$secret #$counter/$secret #$new/" "$otp_file"
        trash "$otp_file.bak"
    fi
}

qr_single() {
    make_tmpdir
    need qrencode
    file="$tmpdir/qr.png"
    create_qr "$file"
    open_and_wait "$file"
}

qr_all() {
    make_tmpdir
    need qrencode
    need montage imagemagick
    args=()
    while read -r line; do
        parse_line "$line"
        if [[ -n "$counter" ]]; then
            echo "note: skipping HOTP $issuer ($account) since it cannot be shared"
            continue
        fi
        file="$tmpdir/$issuer-$account.png"
        create_qr "$file"
        args+=("-label" "$issuer\n($account)" "$file")
    done < "$otp_file"
    file="$tmpdir/combined.png"
    # https://legacy.imagemagick.org/Usage/montage
    montage -geometry 200x200+50+50 "${args[@]}" "$file"
    open_and_wait "$file"
}

qr_decode() {
    need zbarimg zbar
    if ! result=$(zbarimg "$1" 2>/dev/null); then
        die "$1: cannot decode image"
    fi
    code=${result#QR-Code:}
    if [[ "$code" = "$result" ]]; then
        die "$1: not a QR code"
    fi
    if grep -Eq '[a-zA-Z0-9]+-[a-zA-Z0-9]+' <<< "$code"; then
        need jq
        # It's Duo. https://shreyasminocha.me/blog/duo-mobile-2fa/
        token=${code%-*}
        b64=${code#*-}
        pad=$((4 - (${#b64} % 4)))
        pad=$(printf "%0${pad}s" | tr '0' '=')
        domain=$(base64 -d <<< "$b64$pad")
        secret=$( \
            curl -sSf -X POST "https://$domain/push/v2/activation/$token" \
            | tee response.json \
            | jq -r '.response.hotp_secret' \
            | python3 -c \
            "import base64; import sys; print(base64.b32encode(sys.stdin.read().encode()).decode())")
        secret=${secret%%=*}
        echo -n "Enter issuer: "
        read -r issuer
        echo -n "Enter account: "
        read -r account
        counter=0
    else
        path=${code#otpauth://totp/}
        if [[ "$path" = "$code" ]]; then
            die "$1: $code: not an otpauth:// uri"
        fi
        path=${path/&issuer=*/}
        issuer=${path%%:*}
        rest=${path#*:}
        account=${rest%%\?*}
        secret=${rest#*\?secret=}
        if [[ -z "$issuer" || -z "$account" || -z "$secret" ]]; then
            die "$1: $code: cannot decode uri"
        fi
        counter=
    fi
    if [[ $qr == true ]]; then
        qr_single
    elif [[ -n "$counter" ]]; then
        echo "$issuer $account $secret #$counter"
    else
        echo "$issuer $account $secret"
    fi
}

create_qr() {
    if [[ -z "$counter" ]]; then
        uri="otpauth://totp/$issuer:$account?secret=$secret"
    else
        uri="otpauth://hotp/$account?secret=$secret&counter=$counter&issuer=$issuer"
    fi
    echo "$uri"
    qrencode -s 10 -o "$1" "$uri"
}

open_and_wait() {
    open "$1"
    # Give time before ending the script and deleting tmpdir.
    sleep 5
}

main() {
    if [[ -n "$decode" ]]; then
        qr_decode "$decode"
        return
    fi
    if [[ $# -eq 0 ]]; then
        if [[ $qr == true ]]; then
            qr_all
            return
        fi
        usage >&2
        exit 1
    fi
    line=$(grep -i "^$1" < "$otp_file") || :
    if [[ -z "$line" ]]; then
        die "$1: invalid label"
    fi
    parse_line "$line"
    if [[ $qr == true ]]; then
        qr_single
    else
        copy_code
    fi
}

while getopts "hqd:" opt; do
    case $opt in
        h) usage; exit ;;
        q) qr=true ;;
        d) decode=$OPTARG ;;
        *) exit 1 ;;
    esac
done
shift $((OPTIND-1))

main "$@"
