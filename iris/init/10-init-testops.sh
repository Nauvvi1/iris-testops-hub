#!/usr/bin/env bash
set -euo pipefail

echo "[testops-init] Running TestOps initialization..."

# Ensure writable DB directory exists (will be used by Config.Databases)
mkdir -p /usr/irissys/mgr/testops
chown -R irisowner:irisowner /usr/irissys/mgr/testops

iris session IRIS < /opt/testops/iris.script

echo "[testops-init] Done."
