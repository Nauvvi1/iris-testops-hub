#!/usr/bin/env bash
set -euo pipefail

echo "[testops-init] Running TestOps initialization..."

# The IRIS container entrypoint already started the instance before executing initdb scripts.
# We only need to wait until IRIS is responsive, then run our installer script.
for i in $(seq 1 60); do
  if iris session IRIS -U %SYS "write 1" > /dev/null 2>&1; then
    break
  fi
  sleep 2
done

echo "[testops-init] IRIS is responsive, running installer..."
iris session IRIS < /opt/testops/iris.script

echo "[testops-init] Done."
