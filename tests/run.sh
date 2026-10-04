#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
cd "$ROOT_DIR"

bash tests/check-syntax.sh
bash tests/smoke.sh
bash tests/karnel-cli.sh
bash tests/critical-cli.sh
bash tests/pg-supabase.sh
bash tests/open-docs.sh
bash tests/init-search.sh
bash tests/backup-restore.sh
bash tests/brain.sh
bash tests/ai-registry.sh
bash tests/auto-mode.sh
bash tests/completion-catalog.sh
bash tests/lifecycle-orchestration.sh
bash tests/security-supply-chain.sh
bash tests/security-installer-integrity.sh
bash tests/ai-installer-hardening.sh
bash tests/pinned-git-repositories.sh
bash tests/version.sh
bash tests/cli-lifecycle.sh
bash tests/installer.sh
bash tests/npm-postinstall.sh
bash tests/deploy-installers.sh
bash tests/uninstall.sh
bash tests/robin.sh
bash tests/plugins.sh
bash tests/tool-installers.sh
bash tests/installer-handlers.sh
bash tests/installer-globals.sh
bash tests/bun-installer.sh
bash tests/downloaded-python-installers.sh
bash tests/installer-data-safety.sh
bash tests/security-temp-installers.sh
bash tests/security-uninstall-ownership.sh
bash tests/ownership-coverage.sh
bash tests/registry-coverage.sh
bash tests/list-coverage.sh
bash tests/banner.sh
