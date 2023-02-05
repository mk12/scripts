#!/bin/bash

set -eufo pipefail

usage() {
    cat <<EOS
Usage: $0 SOCKET_FILE

Connects to an LSP server on the given Unix domain socket (stream oriented) and
forwards JSON5 commands to it.

Example:

    [Tab1]
    $ gopls serve -listen="unix;gopls.sock" -rpc.trace

    [Tab2]
    $ lsp-cli.sh gopls.sock
    {
        method: "initialize",
        params: {workspaceFolders: [{name: "foo", uri: "file:///path/to/foo"}]}
    }

    {method: "initialized"}

    {
        method: "textDocument/documentSymbol",
        params: {textDocument: {uri: "file:///path/to/foo/some_file.go"}}
    }

After you enter a blank line, the script will convert the input to JSON5, add
the "jsonrpc" and "id" keys, add an empty "params" if there are none, prepend
the "Content-Length" header, send the resulting jsonrpc message to the server,
and print out the reply.
EOS
}

die() {
    echo >&2 "error: $*"
    exit 1
}

process_responses() {
    while :; do
        read -r line
        line=${line%$'\r'}
        len=${line#Content-Length: }
        [[ "$len" =~ ^[0-9]+$ ]] || die "invalid header: $line ($len)"
        read -r line
        [[ "$line" = $'\r' ]] || die "expected \r\n"
        read -r -N "$len" response
        printf "\x1b[34m%s\x1b[0m\n\n" "$(jq . <<< "$response")"
    done
}

case ${1-} in
    ""|-h|--help|help) usage; exit ;;
esac

rm -f nc.in
mkfifo nc.in
nc -U "$1" < nc.in > >(process_responses) &
pid=$!
trap 'kill $pid; rm -f nc.in' EXIT
exec 3> nc.in

id=1
while :; do
    input=
    while read -r line; do
        if [[ -z "$line" ]]; then
            break
        fi
        input+=$line
    done

    json=$(echo "$input" | json5 | jq "
        .jsonrpc = \"2.0\"
        | .id = $id
        | if has(\"params\") then . else .params = {} end
    ")
    printf -v request "Content-Length: %d\r\n\r\n%s" "${#json}" "$json"
    printf "\x1b[32m%s\x1b[0m\n\n" "$request"
    echo -n "$request" >&3
    ((id++))
done
