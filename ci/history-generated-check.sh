#!/usr/bin/env bash
# Regenerate the changed source's aliases and contracts in the disposable upstream tree.
set -euo pipefail
trap 'printf "%s\n" BEGIN_HISTORY_GENERATED_PATCH; git diff --no-ext-diff --binary; printf "%s\n" END_HISTORY_GENERATED_PATCH' EXIT
pnpm run gen-tsconfig-paths
pnpm run gen-cordis-catalog
pnpm run gen-cordis-api
pnpm run gen-module-graph
pnpm run verify-translation-pairing --write \
  packages/boot/plugin-manager/README.md packages/boot/app-boot/README.md \
  apps/desktop/README.md docs/subsystems/boot.md
git diff --exit-code
