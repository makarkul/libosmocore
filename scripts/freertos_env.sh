#!/usr/bin/env bash
# Source this inside the container to setup build flags for FreeRTOS porting attempts.
set -euo pipefail

ROOT_DIR=${ROOT_DIR:-/workspace}
FREERTOS_DEPS_DIR=${FREERTOS_DEPS_DIR:-$ROOT_DIR/deps/freertos}
export PKG_CONFIG_PATH="$ROOT_DIR/build-freertos/lib/pkgconfig:${PKG_CONFIG_PATH:-}"
export CC=${CC:-gcc}
export AR=${AR:-ar}
export CFLAGS="-I$FREERTOS_DEPS_DIR/include/kernel -I$FREERTOS_DEPS_DIR/include/tcp -I$FREERTOS_DEPS_DIR/include/portable/GCC/POSIX ${CFLAGS:-}" 
export LDFLAGS="${LDFLAGS:-}"
export OSMO_FREERTOS=1
echo "[freertos_env] CFLAGS=$CFLAGS"
echo "[freertos_env] Ready. Run scripts/build-libosmocore-freertos.sh"
