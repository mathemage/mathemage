#!/usr/bin/env bash
set -euo pipefail

usage() {
  printf 'Usage: %s [remote]\n' "${0##*/}" >&2
}

if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  usage
  printf 'Run this script inside a git worktree.\n' >&2
  exit 1
fi

current_branch="$(git branch --show-current)"
remote="${1:-}"

if [[ -z "$remote" && -n "$current_branch" ]]; then
  remote="$(git for-each-ref --format='%(upstream:remotename)' "refs/heads/$current_branch")"
fi

if [[ -z "$remote" ]]; then
  if git remote get-url origin >/dev/null 2>&1; then
    remote="origin"
  else
    printf 'Could not determine a remote. Pass the remote name as the first argument.\n' >&2
    exit 1
  fi
fi

if ! git remote get-url "$remote" >/dev/null 2>&1; then
  printf 'Remote not found: %s\n' "$remote" >&2
  exit 1
fi

list_stale_branches() {
  local branch upstream upstream_remote

  while IFS=$'\t' read -r branch upstream upstream_remote; do
    if [[ -n "$current_branch" && "$branch" == "$current_branch" ]]; then
      continue
    fi

    if [[ -z "$upstream" || "$upstream_remote" != "$remote" ]]; then
      continue
    fi

    if ! git show-ref --quiet --verify "$upstream"; then
      printf '%s\n' "$branch"
    fi
  done < <(git for-each-ref refs/heads --format='%(refname:short)%09%(upstream)%09%(upstream:remotename)')
}

git status --short --branch
git branch --format='%(refname:short)'
git remote -v

git fetch --prune "$remote"

mapfile -t stale_branches < <(list_stale_branches)

if ((${#stale_branches[@]} > 0)); then
  printf 'Deleting stale branches for remote %s:\n' "$remote"
  printf '%s\n' "${stale_branches[@]}"
  for branch in "${stale_branches[@]}"; do
    if ! git branch -d "$branch"; then
      printf 'Skipped unmerged branch: %s\n' "$branch" >&2
    fi
  done
else
  printf 'No stale branches found for remote %s.\n' "$remote"
fi

git branch --format='%(refname:short)'

mapfile -t remaining_stale_branches < <(list_stale_branches)

if ((${#remaining_stale_branches[@]} > 0)); then
  printf 'Remaining stale branches for remote %s:\n' "$remote" >&2
  printf '%s\n' "${remaining_stale_branches[@]}" >&2
fi

git status --short --branch
