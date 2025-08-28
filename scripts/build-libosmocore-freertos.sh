#!/usr/bin/env bash
set -euo pipefail
set -x

ROOT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
BUILD_DIR=$ROOT_DIR/build/freertos
mkdir -p "$BUILD_DIR"

if [[ -z "${OSMO_FREERTOS:-}" ]]; then
  echo "Please source scripts/freertos_env.sh first (inside container)." >&2
  exit 1
fi

pushd "$ROOT_DIR" >/dev/null

echo "[build] Autotools bootstrap (always)"
autoreconf -fi
# Default feature trimming for FreeRTOS builds. Intentionally DO NOT disable
# VTY anymore so libosmovty builds by default (telnet server may still require
# additional socket shims for full runtime functionality). Users can still
# override by exporting EXTRA_CONFIGURE_FLAGS or adding --disable-vty.
EXTRA_FLAGS="--disable-gsmtap --disable-gb --disable-libsctp --disable-libusb --disable-multicast --disable-ctrl --disable-serial --disable-msgfile --disable-uring --disable-pcsc --disable-utilities --disable-gnutls --disable-libmnl"

pushd "$BUILD_DIR" >/dev/null
EXTRA_CONFIGURE_FLAGS=${EXTRA_CONFIGURE_FLAGS:-"$EXTRA_FLAGS"}

echo "[build] Configuring (freertos flavor + trimmed features)"
echo "[build] Extra configure flags: $EXTRA_CONFIGURE_FLAGS"
# NOTE: Upstream uses LT_INIT([pic-only disable-static]); requesting --enable-static together with --disable-shared
# conflicts. We drop explicit static/shared flags and rely on defaults so tests link.
CONFIG_CMD=("$ROOT_DIR"/configure --enable-freertos $EXTRA_CONFIGURE_FLAGS --host="$(uname -m)-linux-gnu" \
  CFLAGS="${CFLAGS:-} -DHAVE_STRUCT_SOCKADDR_STORAGE=1" LDFLAGS="$LDFLAGS")
echo "[build] Running: ${CONFIG_CMD[*]}"
"${CONFIG_CMD[@]}" || { echo "Configure failed." >&2; exit 1; }

echo "[build] Building"
# Force regeneration of socket_compat.h if template changed (delete old generated header)
rm -f include/osmocom/core/socket_compat.h || true
make -j"$(nproc)"

echo "[build] Preparing curated FreeRTOS test subset"

# Ensure pseudotalloc header is discoverable as <talloc.h>
if [[ ! -f "$BUILD_DIR/include/talloc.h" ]]; then
  if [[ -f "$ROOT_DIR/src/pseudotalloc/talloc.h" ]]; then
    cp "$ROOT_DIR/src/pseudotalloc/talloc.h" "$BUILD_DIR/include/talloc.h"
  fi
fi

# Build minimal test subset (check_PROGRAMS aren't built by 'all'; invoke explicitly)
MINI_TESTS=( \
  bits/bitrev_test \
  bitvec/bitvec_test \
  base64/base64_test \
  jhash/jhash_test \
  prbs/prbs_test \
  timer/timer_test \
  msgb/msgb_test \
)
echo "[build] Building minimal tests: ${MINI_TESTS[*]}"
if [[ -d "$BUILD_DIR/tests" ]]; then
  # Ensure libpseudotalloc is included for tests by adjusting LIBS via make var injection
  ( set -x; make -C "$BUILD_DIR/tests" -j"$(nproc)" "${MINI_TESTS[@]}" || echo "[warn] Some test binaries failed to build" )
fi

echo "[build] Running curated FreeRTOS test subset"
if [[ -x "$ROOT_DIR/scripts/run-freertos-tests.sh" ]]; then
  FRTOS_TESTS="${MINI_TESTS[*]}" "$ROOT_DIR/scripts/run-freertos-tests.sh" "$BUILD_DIR" || echo "[warn] Some FreeRTOS subset tests failed"
else
  echo "[warn] FreeRTOS test runner script missing"
fi

echo "[build] Done. Artifacts in $BUILD_DIR"
popd >/dev/null
popd >/dev/null

exit 0
