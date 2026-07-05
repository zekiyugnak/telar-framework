#!/usr/bin/env bash
# Asserts that legacy commands do NOT reference any orchestration sidecar
# skill, per master design §2.8 SIDECAR strategy and sub-spec 1 acceptance
# criterion #2.
#
# Usage: bash scripts/check-sidecar-routing.sh
# Exit 0 = clean. Exit 1 = legacy command references a sidecar (bug).

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

# Sidecar skills known to exist or planned. Add to this list as future
# sub-specs introduce sidecars.
SIDECAR_SKILLS=(
  "skills/orchestration/plan-review-gate"
  "skills/orchestration/adversarial-code-review"
  # Sub-spec 6 will add design-review-gate if it follows SIDECAR pattern; sub-spec 7 may add external-tools.
)

# Legacy commands that must NEVER reference an orchestration sidecar.
LEGACY_COMMANDS=(
  "commands/add-feature.md"
  "commands/create-app.md"
  "commands/review-code.md"
  "commands/release-app.md"
  "commands/audit-security.md"
  "commands/audit-accessibility.md"
  "commands/test-app.md"
  "commands/optimize-perf.md"
  "commands/setup-cicd.md"
  "commands/setup-e2e.md"
  "commands/setup-ota.md"
  "commands/upgrade-deps.md"
  "commands/migrate-app.md"
  "commands/design-system.md"
  "commands/update-requirement.md"
)

failures=0
for cmd in "${LEGACY_COMMANDS[@]}"; do
  if [[ ! -f "$cmd" ]]; then
    continue  # command may not exist yet; skip silently
  fi
  for sidecar in "${SIDECAR_SKILLS[@]}"; do
    if grep -q "$sidecar" "$cmd"; then
      echo "FAIL: legacy command $cmd references sidecar $sidecar"
      failures=$((failures + 1))
    fi
  done
done

if [[ $failures -eq 0 ]]; then
  echo "OK: no legacy commands reference orchestration sidecars."
  exit 0
fi
exit 1
