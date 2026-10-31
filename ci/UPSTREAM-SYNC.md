# Upstream sync operation

`ci/upstream-base-tag` is the default upstream version used by apply.sh, local
migration builds, verification and publishing. `BASE_TAG` (apply.sh) and
`DSH_BASE_TAG` (local migration builds) still override it.

The daily sync workflow validates newer descendant tags. A migration PR changes
only this ordinary configuration file, so it does not need workflow-file write
permission. The PR job has contents/pull-requests write access; validation has
only contents/actions read access. Enable GitHub Actions PR creation in repository
Actions settings if repository policy currently disables it.

Successful builds and explicit patch conflicts are stored as 90-day artifacts,
keyed by both the repository and upstream commit SHA. Later runs reuse the newest
matching result. The original conflict run stays failed; subsequent summaries
link to it and clearly show that migration is still blocked. No migration PR is
created for a stored conflict. Changed inputs or expiration trigger validation
again. Dependency, build and infrastructure failures are not stored and are retried.

Use **Run workflow → force** to revalidate unchanged inputs. This also supersedes
an earlier stored conflict. Reusing a successful build still retries PR creation,
so a fixed repository permission does not require another full build. An existing
automation branch left by a failed PR creation is reused only if its tree exactly
matches the expected migration; differing branches require manual review.

Verification runs for pull requests to main, including version changes. A bot PR
may need GitHub's workflow approval before those checks run; confirm its checks
are green before merging. Creating a PR is not proof that all verification jobs
ran. Publishing remains manual, and the sync workflow never merges or releases.

The upstream checkout keeps history because three-way application of the original
patches after a base upgrade needs the old blob objects.
