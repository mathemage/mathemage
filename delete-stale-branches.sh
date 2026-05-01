#!/usr/bin/env bash
set -euo pipefail

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
  local branch

  while IFS= read -r branch; do
    if [[ -n "$current_branch" && "$branch" == "$current_branch" ]]; then
      continue
    fi

    if ! git show-ref --quiet --verify "refs/remotes/$remote/$branch"; then
      printf '%s\n' "$branch"
    fi
  done < <(git for-each-ref refs/heads --format='%(refname:short)')
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
