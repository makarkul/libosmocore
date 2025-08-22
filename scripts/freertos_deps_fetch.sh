#!/usr/bin/env bash
set -euo pipefail

KERNEL_REPO=${FREERTOS_KERNEL_REPO:-"https://github.com/FreeRTOS/FreeRTOS-Kernel.git"}
TCP_REPO=${FREERTOS_TCP_REPO:-"https://github.com/FreeRTOS/FreeRTOS-Plus-TCP.git"}
KERNEL_REF=${FREERTOS_KERNEL_REF:-"V11.1.0"}
TCP_REF=${FREERTOS_TCP_REF:-"V4.1.0"}
DEST_DIR=${FREERTOS_DEPS_DIR:-"$(pwd)/deps/freertos"}

usage() {
  echo "Usage: $0 [--kernel-ref TAG_OR_SHA] [--tcp-ref TAG_OR_SHA]" >&2
}

while [[ $# -gt 0 ]]; do
  case $1 in
    --kernel-ref) KERNEL_REF=$2; shift 2;;
    --tcp-ref) TCP_REF=$2; shift 2;;
    -h|--help) usage; exit 0;;
    *) echo "Unknown arg: $1" >&2; usage; exit 1;;
  esac
done

echo "[freertos_deps] Destination: $DEST_DIR" >&2
mkdir -p "$DEST_DIR"

fetch_repo() {
  local repo=$1 ref=$2 path=$3
  if [[ -d $path/.git ]]; then
    echo "[freertos_deps] Updating $repo -> $ref" >&2
    git -C "$path" fetch --all --tags --prune
  else
    echo "[freertos_deps] Cloning $repo" >&2
    git clone --depth 1 --branch "$ref" "$repo" "$path" || {
      echo "Shallow clone failed, trying full clone" >&2
      git clone "$repo" "$path"
    }
  fi
  git -C "$path" checkout "$ref"
}

fetch_repo "$KERNEL_REPO" "$KERNEL_REF" "$DEST_DIR/FreeRTOS-Kernel"
fetch_repo "$TCP_REPO" "$TCP_REF" "$DEST_DIR/FreeRTOS-Plus-TCP"

echo "[freertos_deps] Symlinking consolidated include directory" >&2
mkdir -p "$DEST_DIR/include"
ln -sf ../FreeRTOS-Kernel/include "$DEST_DIR/include/kernel" 2>/dev/null || true
ln -sf ../FreeRTOS-Kernel/portable "$DEST_DIR/include/portable" 2>/dev/null || true
ln -sf ../FreeRTOS-Plus-TCP/source/include "$DEST_DIR/include/tcp" 2>/dev/null || true

echo "[freertos_deps] Done." >&2
