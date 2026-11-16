#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

VALUES_FILE="envs/dev/values.yaml"

echo "==> Setting app.version=v3-bad, app.failRate=0.5 in ${VALUES_FILE}"
sed -i.bak "s/^  version:.*/  version: \"v3-bad\"/" "$VALUES_FILE"
sed -i.bak "s/^  failRate:.*/  failRate: \"0.5\"/" "$VALUES_FILE"
rm -f "${VALUES_FILE}.bak"

git add "$VALUES_FILE"
git commit -m "release: intentionally bad release v3-bad"
git push

echo "==> Pushed a bad release. The AnalysisRun should fail and the Rollout should abort/degrade automatically."
echo "    Watch it with:"
echo "    kubectl argo rollouts get rollout demo-service -n demo --watch"
echo ""
echo "==> To recover, run:"
echo "    ./scripts/demo-good-release.sh v4"
