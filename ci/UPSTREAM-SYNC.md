English | [中文](UPSTREAM-SYNC.zh-CN.md)

# Upstream synchronization

`ci/upstream-base-tag` is the default version for apply.sh, local migration builds, verification and publishing. `BASE_TAG` and `DSH_BASE_TAG` override it in the corresponding local scripts.

The daily workflow validates newer descendant tags. Migration PRs change the ordinary base file, so they need no workflow-file write permission. Validation has contents/actions read access; PR creation has contents/pull-requests write access. The repository must allow GitHub Actions to create PRs. This setting is enabled for this repository; the default token remains read-only and merging is separate.

Successful builds and explicit patch conflicts are cached as 90-day artifacts keyed by both port-repository and upstream commit SHAs. Later runs reuse the newest exact match. A fresh explicit patch conflict succeeds the run and opens or updates one `Upstream sync blocked: the patch series conflicts with …` issue with the run link and artifact instructions; a conflict reused from the cache does not open another issue, because only a human patch edit can clear it. The summary links the original run and clearly reports migration blocked. No PR is created for a stored conflict. Changed inputs or expiration require validation again. Dependency/build/infrastructure failures still fail the run and are not cached, so they are retried; they are the only failures that notify.

Use **Run workflow → force** to revalidate unchanged inputs and supersede stored conflicts. Reusing success still retries PR creation, so fixing repository permissions does not require another build. A leftover automation branch is reused only when its tree exactly matches the expected migration; different trees require review. Existing matching PRs are reused rather than duplicated.

Relevant PRs to main run Linux verification, including version changes. A bot PR may require GitHub's workflow approval; confirm its actual checks passed before merging. Creating a PR is not evidence that verification ran. Publishing remains manual; synchronization never merges or releases.

Upstream history is retained because three-way application after a base upgrade needs old blob objects. The script stages patches with `git apply --3way`: `git write-tree` records the patched tree, while `HEAD` still identifies the checked-out base.
