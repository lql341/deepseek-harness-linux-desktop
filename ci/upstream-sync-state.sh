#!/usr/bin/env bash
# Reuse only results produced by this workflow for the exact repository/upstream SHA pair.
# Artifact expiration bounds reuse to 90 days. --force in the workflow bypasses this lookup.
set -euo pipefail

[[ ${1:-} == restore ]] || { echo 'usage: upstream-sync-state.sh restore' >&2; exit 2; }
name="sync-result-$GITHUB_SHA-$UPSTREAM_SHA"
artifact=$(gh api --method GET "repos/$GITHUB_REPOSITORY/actions/artifacts" \
  -f name="$name" -f per_page=100 \
  --jq '[.artifacts[] | select(.expired == false)] | sort_by(.id) | reverse | .[0].workflow_run.id // empty')
if [[ -z "$artifact" ]]; then exit 0; fi

# Do not consume an artifact with the same name from another workflow or a PR run.
trusted=$(gh api "repos/$GITHUB_REPOSITORY/actions/runs/$artifact" | \
  jq -r --arg sha "$GITHUB_SHA" \
  '.head_sha == $sha and .path == ".github/workflows/upstream-sync-check.yml" and .head_branch == "main" and (.event == "schedule" or .event == "workflow_dispatch")')
[[ "$trusted" == true ]] || exit 0
result_dir=$(mktemp -d)
trap 'rm -rf -- "$result_dir"' EXIT
gh run download "$artifact" --repo "$GITHUB_REPOSITORY" --name "$name" --dir "$result_dir"
status=$(cat "$result_dir/sync-validation-status.txt")
case "$status" in
  success|conflict)
    printf 'status=%s\n' "$status" >> "$GITHUB_OUTPUT"
    printf 'Reusing %s from %s/%s/actions/runs/%s\n' "$status" "$GITHUB_SERVER_URL" "$GITHUB_REPOSITORY" "$artifact" >> "$GITHUB_STEP_SUMMARY"
    ;;
  *) echo '::warning::Invalid stored validation status; revalidating.' ;;
esac
