#!/usr/bin/env bash
# Regenerate the changed source's aliases and contracts in the disposable upstream tree.
set -euo pipefail
trap 'printf "%s\n" BEGIN_HISTORY_GENERATED_PATCH; git diff --no-ext-diff --binary; printf "%s\n" END_HISTORY_GENERATED_PATCH' EXIT
status=0
pnpm run gen-tsconfig-paths || status=1
pnpm run gen-cordis-catalog || status=1
pnpm run gen-cordis-api || status=1
pnpm run gen-module-graph || status=1
pnpm run verify-translation-pairing --write \
  packages/boot/plugin-manager/README.md packages/boot/app-boot/README.md \
  apps/desktop/README.md docs/subsystems/boot.md || status=1
git diff --quiet || status=1
exit "$status"
