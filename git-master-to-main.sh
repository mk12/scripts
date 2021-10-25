#!/bin/bash

set -eufo pipefail

die() {
    echo "$*" >&2
    exit 1
}

step() {
    echo "> $*"
    "$@"
}

[[ -d .git ]] || die "not in a git repo"

echo -n "Copy token from https://github.com/settings/tokens/new with repo permissions: "
read -r token
[[ -n "$token" ]] || die "token is empty"

user=mk12
repo=$(basename "$(pwd)")
git remote -v | grep -F "git@github.com:$user/$repo" || die "not on github"

step git branch -m master main
step git push -u origin main
step git symbolic-ref refs/remotes/origin/HEAD refs/remotes/origin/main
step curl --fail -X PATCH \
    -u "$user:$token" \
    -H 'Content-Type: application/json' \
    -H "Accept: application/vnd.github.v3+json" \
    -d "{\"name\": \"$repo\", \"default_branch\": \"main\"}" \
    "https://api.github.com/repos/$user/$repo"
step git push origin --delete master
