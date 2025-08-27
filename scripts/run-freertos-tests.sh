#!/usr/bin/env bash
set -euo pipefail

# run-freertos-tests.sh
# Lightweight test runner for the FreeRTOS build. We cannot rely on the full
# GNU Autotest harness (testsuite) because many subsystems are disabled. This
# script simply executes a curated allowlist of self-contained unit tests that
# don't depend on disabled features (CTRL, VTY, GB, utilities, io_uring, etc.).
#
# Override allowlist:
#   FRTOS_TESTS="space separated relative paths under tests/" ./scripts/run-freertos-tests.sh
# Or provide a file with one test per line:
#   FRTOS_TESTS_FILE=freertos-tests.txt ./scripts/run-freertos-tests.sh
#
# Exit code: 0 if all selected tests pass; 1 if any fail; 2 if no tests executed.

ROOT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
BUILD_DIR=${1:-"$ROOT_DIR/build/freertos"}
TEST_DIR="$BUILD_DIR/tests"

if [[ ! -d "$TEST_DIR" ]]; then
  echo "[fr-tests] Test directory not found: $TEST_DIR" >&2
  exit 2
fi

default_allow=(
  bits/bitrev_test
  bitvec/bitvec_test
  base64/base64_test
  jhash/jhash_test
  prbs/prbs_test
  timer/timer_test
  msgb/msgb_test
  tlv/tlv_test
)

if [[ -n "${FRTOS_TESTS_FILE:-}" ]]; then
  if [[ -f "$FRTOS_TESTS_FILE" ]]; then
    mapfile -t allow < <(grep -vE '^#|^$' "$FRTOS_TESTS_FILE")
  else
    echo "[fr-tests] FRTOS_TESTS_FILE not found: $FRTOS_TESTS_FILE" >&2
    exit 2
  fi
elif [[ -n "${FRTOS_TESTS:-}" ]]; then
  # shellcheck disable=SC2206
  allow=($FRTOS_TESTS)
else
  allow=(${default_allow[@]})
fi

total=0
passed=0
failed=0
missing=0
declare -a failed_list

echo "[fr-tests] Building required test binaries (subset)..."
pushd "$TEST_DIR" >/dev/null
to_build=()
for rel in "${allow[@]}"; do
  if [[ ! -x "$rel" ]]; then
    to_build+=("$rel")
  fi
done
if [[ ${#to_build[@]} -gt 0 ]]; then
  # Use make with parallelism; ignore failures here to allow reporting later
  echo "[fr-tests] make -j$(nproc) ${to_build[*]}"
  if ! make -j"$(nproc)" ${to_build[*]} >/dev/null 2>&1; then
    echo "[fr-tests] Warning: some test build steps failed; will attempt to run what exists" >&2
  fi
fi
popd >/dev/null

echo "[fr-tests] Starting FreeRTOS applicable test subset..."
for rel in "${allow[@]}"; do
  bin="$TEST_DIR/$rel"
  if [[ ! -x "$bin" ]]; then
    echo "[skip] $rel (missing)" >&2
    ((missing++)) || true
    continue
  fi
  ((total++)) || true
  echo -n "[run ] $rel ... "
  set +e
  "$bin" >"$bin.log" 2>&1
  rc=$?
  set -e
  if [[ $rc -eq 0 ]]; then
    echo "ok"
    ((passed++)) || true
  else
    echo "FAIL (rc=$rc)" >&2
    failed_list+=("$rel")
    ((failed++)) || true
  fi
done

# Fallback auto-discovery if nothing from allowlist executed
if [[ $total -eq 0 ]]; then
  echo "[fr-tests] Allowlist produced no runnable tests; auto-discovering *_test executables" >&2
  mapfile -t discovered < <(cd "$TEST_DIR" && find . -maxdepth 3 -type f -perm -u+x -name '*_test' | sed 's#^./##' | sort)
  for rel in "${discovered[@]}"; do
    bin="$TEST_DIR/$rel"
    [[ -x "$bin" ]] || continue
    echo -n "[auto] $rel ... "
    set +e; "$bin" >"$bin.log" 2>&1; rc=$?; set -e
    if [[ $rc -eq 0 ]]; then
      echo ok; ((passed++)) || true; ((total++)) || true
    else
      echo FAIL >&2; failed_list+=("$rel"); ((failed++)) || true; ((total++)) || true
    fi
  done
fi

echo "[fr-tests] Summary: total=$total passed=$passed failed=$failed missing=$missing"
if [[ $failed -gt 0 ]]; then
  echo "[fr-tests] Failed tests:" >&2
  printf '  %s\n' "${failed_list[@]}" >&2
  exit 1
fi
if [[ $total -eq 0 ]]; then
  echo "[fr-tests] No tests executed after auto-discovery." >&2
  exit 2
fi
exit 0
