#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

VERSION="${1:-v2}"
VALUES_FILE="envs/dev/values.yaml"

echo "==> Setting app.version=${VERSION}, app.failRate=0 in ${VALUES_FILE}"
sed -i.bak "s/^  version:.*/  version: \"${VERSION}\"/" "$VALUES_FILE"
sed -i.bak "s/^  failRate:.*/  failRate: \"0\"/" "$VALUES_FILE"
rm -f "${VALUES_FILE}.bak"

git add "$VALUES_FILE"
git commit -m "release: good release ${VERSION}"
git push

echo "==> Pushed. Watch the rollout with:"
echo "    kubectl argo rollouts get rollout demo-service -n demo --watch"
