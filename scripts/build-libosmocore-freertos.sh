#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
BUILD_DIR=$ROOT_DIR/build-freertos
mkdir -p "$BUILD_DIR"

if [[ -z "${OSMO_FREERTOS:-}" ]]; then
  echo "Please source scripts/freertos_env.sh first (inside container)." >&2
  exit 1
fi

pushd "$ROOT_DIR" >/dev/null

echo "[build] Autotools bootstrap"
# Re-run autoreconf if configure missing or template for socket_compat changed after last configure
if [[ ! -f configure ]] || [[ include/osmocom/core/socket_compat.h.tpl -nt configure ]]; then
  autoreconf -fi
fi
EXTRA_FLAGS="--disable-gsmtap --disable-gb --disable-libsctp --disable-libusb --disable-multicast --disable-vty --disable-ctrl --disable-serial --disable-msgfile --disable-uring --disable-pcsc --disable-utilities --disable-gnutls --disable-libmnl"

pushd "$BUILD_DIR" >/dev/null
EXTRA_CONFIGURE_FLAGS=${EXTRA_CONFIGURE_FLAGS:-"$EXTRA_FLAGS"}

echo "[build] Configuring (freertos flavor + trimmed features)"
echo "[build] Extra configure flags: $EXTRA_CONFIGURE_FLAGS"
"$ROOT_DIR"/configure --disable-shared --enable-static --enable-freertos $EXTRA_CONFIGURE_FLAGS --host="$(uname -m)-linux-gnu" \
  CFLAGS="${CFLAGS:-} -DHAVE_STRUCT_SOCKADDR_STORAGE=1" LDFLAGS="$LDFLAGS" || {
    echo "Configure failed." >&2; exit 1; }

echo "[build] Building"
# Force regeneration of socket_compat.h if template changed (delete old generated header)
rm -f include/osmocom/core/socket_compat.h || true
make -j"$(nproc)"

echo "[build] Running curated FreeRTOS test subset"
if [[ -x "$ROOT_DIR/scripts/run-freertos-tests.sh" ]]; then
  "$ROOT_DIR/scripts/run-freertos-tests.sh" "$BUILD_DIR" || echo "[warn] Some FreeRTOS subset tests failed"
else
  echo "[warn] FreeRTOS test runner script missing"
fi

echo "[build] Done. Artifacts in $BUILD_DIR"
popd >/dev/null
popd >/dev/null
