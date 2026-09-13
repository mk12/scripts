#!/bin/bash

set -Eeufo pipefail
trap 'echo >&2 "$0:$LINENO [$?]: $BASH_COMMAND"' ERR

usage() {
    cat <<EOF
Usage: $0 URL

Measure how long an HTTP server keeps open a keep-alive connection
EOF
}

case ${1-} in
    ""|-h|--help) usage; exit ;;
    -*) usage >&2; exit 1 ;;
esac

connect_nc() {
    nc "$1" "$2"
}

connect_openssl() {
    openssl s_client -connect "$1:$2" -quiet
}

url=$1

if [[ "$url" = 'http://'* ]]; then
    scheme=http
    default_port=80
    connect=connect_nc
elif [[ "$url" = 'https://'* ]]; then
    scheme=https
    default_port=443
    connect=connect_openssl
else
    echo >&2 "$url: invalid scheme"
    exit 1
fi

after=${url#$scheme://}
authority=${after%%/*}
if [[ "$authority" = "$after" ]]; then
    path=/
else
    path=${after#*/}
fi

if [[ "$authority" = *:* ]]; then
    host=${authority%%:*}
    port=${authority#*:}
else
    host=$authority
    port=$default_port
fi

if [[ -z "$host" || -z "$port" ]] || ! [[ "$port" =~ [0-9]+ ]]; then
    echo >&2 "$url: invalid host or port"
    exit 1
fi

echo "* scheme: $scheme, host: $host, port: $port"
{
    printf "GET %s HTTP/1.1\r\nHost: %s\r\n\r\n" "$path" "$host"
    sleep 300
} | tee /dev/tty | "$connect" "$host" "$port"
