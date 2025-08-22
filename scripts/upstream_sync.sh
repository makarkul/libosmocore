#!/usr/bin/env bash
set -euo pipefail

# upstream_sync.sh
# Helper to synchronize this fork (with FreeRTOS additions) with upstream Osmocom libosmocore.
#
# Remotes assumptions:
#   origin = upstream (https://gitea.osmocom.org/osmocom/libosmocore.git)
#   github = GitHub fork (https://github.com/makarkul/libosmocore.git)
#
# Default mode: merge origin/master into current branch (typically master) and push to github.
# You can choose a rebase instead of merge.
#
# Features:
#   --merge (default)  Perform a merge of origin/master
#   --rebase           Rebase current branch onto origin/master instead of merge
#   --branch <name>    Branch to update (default: master). Will checkout.
#   --push             Push result to github remote
#   --no-push          Do not push (default if --push not given)
#   --mirror-upstream  Maintain/update a local branch 'upstream-master' that exactly matches origin/master
#   --dry-run          Show what would be done without executing merge/rebase/push
#   -h|--help          Usage help
#
# Exit codes:
#   0 success, non-zero on failure/conflict or invalid state.

usage() {
  grep '^#' "$0" | sed 's/^# //;s/^#//' | sed -n '1,/^$/p'
  echo "Usage: $0 [--merge|--rebase] [--branch <name>] [--push] [--mirror-upstream] [--dry-run]" >&2
}

mode=merge
branch=master
do_push=false
mirror=false
dry=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --merge) mode=merge ; shift ;;
    --rebase) mode=rebase ; shift ;;
    --branch) branch=$2 ; shift 2 ;;
    --push) do_push=true ; shift ;;
    --no-push) do_push=false ; shift ;;
    --mirror-upstream) mirror=true ; shift ;;
    --dry-run) dry=true ; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown arg: $1" >&2; usage; exit 1 ;;
  esac
done

require_clean() {
  if ! git diff --quiet || ! git diff --cached --quiet; then
    echo "ERROR: Working tree not clean. Commit/stash first." >&2
    exit 2
  fi
}

info() { echo "[sync] $*"; }
run() { if $dry; then echo "DRY: $*"; else eval "$@"; fi }

# Basic validation of remotes
origin_url=$(git remote get-url origin 2>/dev/null || true)
if [[ -z "$origin_url" ]]; then
  echo "ERROR: 'origin' remote missing." >&2
  exit 3
fi
github_url=$(git remote get-url github 2>/dev/null || true)
if [[ -z "$github_url" ]]; then
  info "github remote missing; add with: git remote add github https://github.com/<user>/libosmocore.git"
fi

require_clean

info "Fetching remotes..."
run git fetch origin --prune
if [[ -n "$github_url" ]]; then
  run git fetch github --prune || true
fi

if $mirror; then
  info "Updating mirror branch upstream-master -> origin/master"
  # Create or update upstream-master to point exactly at origin/master
  if $dry; then
    echo "DRY: git update-ref refs/heads/upstream-master origin/master (force)"
  else
    git show-ref --verify --quiet refs/heads/upstream-master || git branch upstream-master origin/master
    # Force move
    git update-ref refs/heads/upstream-master refs/remotes/origin/master
  fi
fi

current_branch=$(git rev-parse --abbrev-ref HEAD)
if [[ "$current_branch" != "$branch" ]]; then
  info "Checking out branch $branch"
  run git checkout "$branch"
fi

info "Ensuring local $branch has no unpushed commits before sync (good practice)"
if git rev-parse github/$branch >/dev/null 2>&1; then
  ahead=$(git rev-list --left-right --count github/$branch...$branch | awk '{print $2}')
  if [[ $ahead -gt 0 ]]; then
    info "Local branch ahead of github by $ahead commit(s); will still proceed."
  fi
fi

upstream_ref=origin/master
if [[ "$branch" != "master" ]]; then
  upstream_ref="origin/$branch"
fi

if ! git show-ref --verify --quiet refs/remotes/$upstream_ref; then
  echo "ERROR: Upstream ref $upstream_ref not found" >&2
  exit 4
fi

info "Sync mode: $mode with upstream $upstream_ref"

case $mode in
  merge)
    base_diff=$(git rev-list --left-right --count $branch...$upstream_ref | awk '{print $1" "$2}')
    info "Merge stats (ahead behind): $base_diff"
    run git merge --no-edit $upstream_ref || {
      echo "Merge conflict. Resolve manually then: git add <files>; git commit; (rerun with --push if needed)" >&2
      exit 5
    }
    ;;
  rebase)
    run git rebase $upstream_ref || {
      echo "Rebase conflict. Fix, then 'git rebase --continue' or 'git rebase --abort'." >&2
      exit 6
    }
    ;;
esac

if $do_push; then
  if [[ -z "$github_url" ]]; then
    echo "ERROR: github remote not configured; cannot push." >&2
    exit 7
  fi
  info "Pushing branch $branch to github"
  run git push github "$branch"
fi

info "Done."
if $dry; then
  info "(Dry run: no changes made)"
fi
