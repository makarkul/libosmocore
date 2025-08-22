#!/usr/bin/env bash
#!/usr/bin/env bash
# Unified build wrapper for libosmocore variants.
#
# Usage:
#   ./build.sh [platform=linux|freertos] <command> [extra=...]
#
# Commands (positional, replaces prior target= syntax):
#   build   -> full build
#   check   -> build + run tests
#   clean   -> remove build artifacts
#   shell   -> open development shell (containerized)
#              Inside the shell run:
#                FreeRTOS:  scripts/build-libosmocore-freertos.sh   (build + mini tests)
#                           or set EXTRA_CONFIGURE_FLAGS then rerun same script
#                Linux:     ./build.sh platform=linux check         (full build + tests)
#
# Legacy target=all|test|clean|shell still works but is deprecated.
# platform must be provided via platform=... (no positional platform argument).
# If platform omitted defaults to linux.
#
# For platform=freertos this script delegates to docker compose services.
# For platform=linux it always builds inside a container.
set -euo pipefail

platform=linux
target=all   # internal target mapping (all|check|clean|shell)
extra=""
cmd=""
explicit_target_set=false

print_help() {
  sed -n '1,60p' "$0" | grep -E '^#' | sed 's/^# ?//'
}

for arg in "$@"; do
  case "$arg" in
    help|-h|--help) print_help; exit 0 ;;
    platform=*|--platform=*|PLATFORM=*) platform="${arg#*=}" ;;
    target=*|--target=*|TARGET=*) target="${arg#*=}"; explicit_target_set=true ;;
    extra=*|--extra=*|EXTRA_FLAGS=*) extra="${arg#*=}" ;;
  build|check|clean|shell|all)
      # first non-assignment arg interpreted as command
      if [[ -z "$cmd" ]]; then cmd="$arg"; else echo "[warn] Ignoring extra command '$arg'" >&2; fi ;;
    *) echo "[warn] Unrecognized argument: $arg" >&2 ;;
  esac
done

if [[ -n "$cmd" ]]; then
  case "$cmd" in
  build|all) target=all ;;
  check) target=check ;;
    clean) target=clean ;;
    shell) target=shell ;;
  esac
fi

case "$platform" in
  linux|freertos) : ;; 
  *) echo "[error] Unsupported platform: $platform" >&2; exit 2 ;;
esac
case "$target" in
  all|clean|check|shell) : ;;
  *) echo "[error] Unsupported target: $target" >&2; exit 2 ;;
esac

echo "[build.sh] platform=$platform target=$target extra='${extra}'"

ROOT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

BUILD_ROOT="$ROOT_DIR/build"
FREERTOS_BUILD_DIR="$BUILD_ROOT/freertos"
LINUX_BUILD_DIR="$BUILD_ROOT/linux"

# Migrate legacy dirs if present
if [[ -d "$ROOT_DIR/build-freertos" && ! -d "$FREERTOS_BUILD_DIR" ]]; then
  mkdir -p "$BUILD_ROOT"
  mv "$ROOT_DIR/build-freertos" "$FREERTOS_BUILD_DIR"
fi
if [[ -d "$ROOT_DIR/build-linux" && ! -d "$LINUX_BUILD_DIR" ]]; then
  mkdir -p "$BUILD_ROOT"
  mv "$ROOT_DIR/build-linux" "$LINUX_BUILD_DIR"
fi

if [[ "$platform" == freertos ]]; then
  # Ensure docker-compose file exists
  if [[ ! -f "$ROOT_DIR/docker-compose.yml" ]]; then
    echo "[error] docker-compose.yml not found" >&2; exit 3
  fi
  # Map targets to services/commands
  case "$target" in
    all)
      exec docker compose run --rm -e EXTRA_CONFIGURE_FLAGS="$extra" build ;;
    check)
      # build script already runs tests; reuse same service
      exec docker compose run --rm -e EXTRA_CONFIGURE_FLAGS="$extra" build ;;
    clean)
      echo "[clean] Removing FreeRTOS build directory" >&2
  rm -rf "$FREERTOS_BUILD_DIR" || true
      exit 0 ;;
    shell)
      exec docker compose run --rm shell ;;
  esac
  exit 0
fi

# Linux (host or container) build path
# Always build inside container for linux platform
if [[ "$platform" == linux ]]; then
  if [[ "$extra" == *"--enable-pseudotalloc"* ]]; then
    echo "[warn] --enable-pseudotalloc ignored for linux; using system libtalloc." >&2
  fi
  # Pass extra flags via env var to container command
  if [[ -n "$extra" ]]; then
    export LINUX_EXTRA_FLAGS="$extra"
  fi
fi
configure_and_build() {
  mkdir -p "$LINUX_BUILD_DIR"
  pushd "$ROOT_DIR" >/dev/null
  echo "[linux] autoreconf (forced)"
  autoreconf -fi
  pushd "$LINUX_BUILD_DIR" >/dev/null
  if [[ ! -f Makefile ]] || [[ "$extra" != "" ]]; then
    echo "[linux] configure $extra"
  eval "$ROOT_DIR/configure" ${extra}
  fi
  echo "[linux] make -j$(nproc)"
  make -j"$(nproc)"
  popd >/dev/null
  popd >/dev/null
}

if [[ "$platform" == linux ]]; then
  if [[ -z "${OSMO_BUILD_IN_CONTAINER:-}" ]]; then
    # outer host invocation -> delegate to container
    case "$target" in
      all)
        exec docker compose run --rm linux ;;
      check)
        exec docker compose run --rm linux bash -lc "./build.sh platform=linux target=all && cd build/linux && make check" ;;
      clean)
        echo "[clean] Removing build/linux" >&2; rm -rf "$LINUX_BUILD_DIR" || true; exit 0 ;;
      shell)
        exec docker compose run --rm linux-shell ;;
    esac
  else
    # inside container: perform actual build
    case "$target" in
      all)
        configure_and_build ;;
      check)
        configure_and_build; echo "[linux] make check"; (cd "$LINUX_BUILD_DIR" && make check) ;;
      clean)
        echo "[clean] Removing build/linux" >&2; rm -rf "$LINUX_BUILD_DIR" || true ;;
      shell)
        echo "[linux] In-container shell" >&2; exec bash ;;
    esac
    exit 0
  fi
fi

