#!/bin/bash

set -Eeufo pipefail
trap 'echo >&2 "$0:$LINENO [$?]: $BASH_COMMAND"' ERR

if [[ -z "$TMUX" ]]; then
    echo >&2 "error: not in tmux"
    exit 1
fi

target=()
if [[ $# -ge 1 ]]; then
    target=(-t "$1")
fi

json=$(mktemp)
output=$(mktemp)
trap 'rm -f "$json" "$output"' EXIT

tmux capture-pane -J -S -100000 -e -p "${target[@]+"${target[@]}"}" | gawk '
BEGIN { n = -1; }
{ p = gensub(/\x1b\[[0-9;]*m/, "", "g"); }
match(p, /^❯(❯)?( (.*))?$/, m) { cmds[++n] = m[3]; b[0] = b[1] = ""; next; }
n >= 0 { out[n] = out[n] b[bi]; b[bi++] = $0 "\n"; bi %= 2; }
function esc(str) {
    sub(/^\n*/, "", str);
    sub(/\n*$/, "", str);
    gsub(/\\/, "\\\\", str)
    gsub(/\n/, "\\n", str);
    gsub(/"/, "\\\"", str);
    gsub(/\x1b/, "\\u001b", str);
    return "\"" str "\"";
}
END {
    out[n] = out[n] b[bi] b[(bi+1)%2];
    print "[";
    comma = 0;
    for (i = n - 1; i >= 0; i--) {
        c = cmds[i]; o = out[i];
        if (o ~ /^\s*$/) continue;
        if (comma) print ",";
        comma = 1;
        printf "{ \"cmd\": %s, \"out\": %s }", esc(cmds[i]), esc(out[i]);
    }
    print "]";
}' > "$json"

index=$(jq 'to_entries | .[] | "\(.key)❯ \(.value.cmd)"' "$json" -r \
    | fzf --scheme=history --height 100% --preview-window=down,95% --ansi \
        --preview="jq '.[{n}] | .out' '$json' -r" \
    | rg '^\d+' -o)

jq --arg index "$index" '.[$index | tonumber] | .out' "$json" -r \
    | sed -e 's/\x1b\[[0-9;]*m//g' > "$output"

"$EDITOR" "$output"
