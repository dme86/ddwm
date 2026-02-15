#!/bin/bash
cd "$(dirname "$0")/.."
source ./script/setup.sh

if ! git rev-parse --is-inside-work-tree > /dev/null 2>&1; then
    echo "warning: Not a git worktree. Skipping uncommitted files check" > /dev/stderr
    exit 0
fi

if ! test -z "$(git status --porcelain)"; then
    echo !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
    echo !!! Uncommitted files detected !!!
    echo !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
    git diff | sed 's/^/    /'
    echo !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
    echo !!! Uncommitted files detected !!!
    echo !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
    exit 1
fi
