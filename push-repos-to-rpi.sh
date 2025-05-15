#!/bin/bash

set -euo pipefail

run () {
    printf "\e[32;1m\$ $*\e[0m\n"
    "$@"
}

init_rpi_remote() {
    path=/z/code/$(basename "$1").git
    run git remote add rpi rpi:$path || :
    run ssh rpi "git init --bare $path"
    run git push rpi main
}

add_all_remote() {
    git remote -v | grep -q 'origin.*github' || return
    run git remote rename origin github
    run git config --add remote.all.pushurl $(git remote get-url github)
    run git config --add remote.all.pushurl $(git remote get-url rpi)
}

remove_all_remote() {
    git remote -v | grep -q '^all' || return
    git remote rm all
    git config --unset remote.pushDefault
}

push_main() {
    git remote -v | grep -q '^all' || return
    [[ -z "$(git diff)" ]] || return
    git rev-parse --verify main || return
    git config remote.pushDefault all
    git push all main
}

for_mine() {
    :
}

for_others() {
    :
}

email=$(git config user.email)
for dir in ~/Code/*; do
    if ! [[ -d "$dir/.git" ]]; then
        continue
    fi
    run cd "$dir"
    author=$(git log --format='%ae' $(git rev-list --max-parents=0 HEAD | head -n1))
    if [[ "$author" = "$email" ]]; then
        for_mine "$dir" &
    else
        for_others "$dir" &
    fi
    sleep 0.1
done
wait
