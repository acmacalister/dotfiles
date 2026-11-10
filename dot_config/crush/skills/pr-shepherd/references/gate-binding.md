# Exact-head gate binding

Use this reference from the `pr-shepherd` skill. All evidence must bind to the current PR head SHA.

## Commit statuses

```bash
PR=<number>
OWNER_REPO=$(gh repo view --json nameWithOwner -q .nameWithOwner)
HEAD_SHA=$(gh pr view "$PR" --json headRefOid -q .headRefOid)

gh api "repos/$OWNER_REPO/commits/$HEAD_SHA/status" \
  --jq '{state,statuses:[.statuses[]|{context,state,description,target_url,updated_at}]}'

gh api "repos/$OWNER_REPO/commits/$HEAD_SHA/check-runs" \
  --jq '{total:.total_count,runs:[.check_runs[]|{name,status,conclusion,details_url}]}'
```

Require exact contexts for terminal-clean / merge:

- `RWX: ci.yml (pull request)` → `success` (always required)
- `RWX: playwright-e2e.yml (pull request)` → `success` when the check exists for this PR; if the repo never emits it for this path, document N/A only after CI is green
- `curri/pr-review` → `success` (always required before merge)

Extract each RWX run ID from the final path segment of `target_url`.

A context/check name containing `codeowner` is optional for reporting; still honor branch protection if merge is blocked by it.

## Generated body block

```bash
gh api "repos/$OWNER_REPO/pulls/$PR" --jq '{head:.head.sha,body:.body}'
```

Slice from:

```text
<!-- generated_for: <40-char SHA> -->
```

through:

```text
<!-- curri:pr-review:end -->
```

(or the repo’s equivalent marker-fenced pr-review section).

Require **all** of:

1. Marker SHA equals `HEAD_SHA` (exact head bind).
2. **`Confidence Score: 5/5`** (or equivalent `5/5` in the confidence section). Anything else (missing, 4/5, 3/5, …) **blocks merge**.
3. **`Findings (0)`** / empty Findings section (no P0/P1/P2/Important/Suggestion items).

```bash
# Example extraction helpers (adjust if body format differs):
BODY=$(gh api "repos/$OWNER_REPO/pulls/$PR" --jq .body)
echo "$BODY" | grep -E 'Confidence Score:[[:space:]]*5/5' || echo "BLOCK: confidence not 5/5"
echo "$BODY" | grep -E 'Findings \(0\)|## Findings[[:space:]]*$' || true
```

## Review event

```bash
gh api "repos/$OWNER_REPO/pulls/$PR/reviews" \
  --jq ".[] | select(.user.login==\"agents-pipeline[bot]\" and .commit_id==\"$HEAD_SHA\") | {id,state,commit_id,body}"
```

Prefer at least one exact-head review with `state == "APPROVED"`.  
**Merge is still forbidden** while any automated finding remains or any bot review thread is unresolved—even if the event is `APPROVED` or `COMMENTED`. If quoting becomes ambiguous, dump the JSON and filter it with a small script; do not use unsupported `gh --jq --arg` combinations.

## Review threads

Use GraphQL so resolved state is visible:

```graphql
query($owner:String!, $repo:String!, $number:Int!) {
  repository(owner:$owner, name:$repo) {
    pullRequest(number:$number) {
      reviewThreads(first:100) {
        nodes {
          id
          isResolved
          path
          line
          originalLine
          comments(first:100) {
            nodes {
              id
              url
              body
              author { login }
              commit { oid }
              originalCommit { oid }
            }
          }
        }
        pageInfo { hasNextPage endCursor }
      }
    }
  }
}
```

Paginate when `hasNextPage` is true. An automated thread is any thread containing a comment whose author is `agents-pipeline[bot]`. Final gate: every such thread has `isResolved == true`.

## Final atomic snapshot

Immediately before reporting clean, re-fetch PR head, statuses, body, reviews, and threads. Abort the clean verdict if the head changed during collection.
