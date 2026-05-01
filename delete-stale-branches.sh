#!/usr/bin/env bash
set -euo pipefail

current_branch="$(git branch --show-current)"

git status --short --branch
git branch --format='%(refname:short)'
git remote -v

git fetch --prune origin

mapfile -t stale_branches < <(
  for branch in $(git for-each-ref refs/heads --format='%(refname:short)'); do
    if [[ "$branch" == "$current_branch" ]]; then
      continue
    fi

    if ! git show-ref --quiet --verify "refs/remotes/origin/$branch"; then
      printf '%s\n' "$branch"
    fi
  done
)

if ((${#stale_branches[@]} > 0)); then
  printf '%s\n' "${stale_branches[@]}"
  git branch -D "${stale_branches[@]}"
fi

git branch --format='%(refname:short)'

for branch in $(git for-each-ref refs/heads --format='%(refname:short)'); do
  if [[ "$branch" == "$current_branch" ]]; then
    continue
  fi

  if ! git show-ref --quiet --verify "refs/remotes/origin/$branch"; then
    printf '%s\n' "$branch"
  fi
done

git status --short --branch
