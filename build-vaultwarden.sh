#!/bin/bash

set -Eeufo pipefail
trap 'echo >&2 "$0:$LINENO [$?]: $BASH_COMMAND"' ERR

usage() {
    cat <<EOF
Usage: $0

Build vaultwarden for hex

Options:
    -v VERSION  Vaultwarden version (default: latest)
EOF
}

v=latest

while [[ $# -gt 0 ]]; do
    arg=$1; shift
    case $arg in
        -h|--help|"") usage; exit ;;
        -v) v=$1; shift ;;
        *) usage >&2; exit 1 ;;
    esac
done

run() {
    echo "> $*"
    "$@"
}

tmp_zig_cc=$(mktemp)
trap 'rm -f "$tmp_zig_cc"' EXIT
cat <<'EOF' > "$tmp_zig_cc"
#!/bin/sh
zig cc -target x86_64-linux-gnu.2.41 "$@"
EOF
chmod +x "$tmp_zig_cc"

spec=vaultwarden
if [[ "$v" != latest ]]; then
    spec=vaultwarden@$v
fi

echo "Building vaultwarden $v"
run mkdir ~/Downloads/vaultwarden-$v
run cd ~/Downloads/vaultwarden-$v
run cargo install "$spec" \
    --root . \
    --target x86_64-unknown-linux-gnu \
    --config "target.x86_64-unknown-linux-gnu.linker=\"$tmp_zig_cc\""

echo "Copying to hex"
run scp ~/Downloads/vaultwarden-$v/bin/vaultwarden hex:

echo "Now manually move it to /usr/local/bin/vaultwarden"
