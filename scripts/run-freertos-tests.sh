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
BUILD_DIR=${1:-"$ROOT_DIR/build-freertos"}
TEST_DIR="$BUILD_DIR/tests"

if [[ ! -d "$TEST_DIR" ]]; then
  echo "[fr-tests] Test directory not found: $TEST_DIR" >&2
  exit 2
fi

default_allow=(
  a5/a5_test
  bits/bitrev_test
  bitvec/bitvec_test
  bits/bitcomp_test
  bits/bitfield_test
  conv/conv_test
  conv/conv_gsm0503_test
  coding/coding_test
  kasumi/kasumi_test
  gea/gea_test
  comp128/comp128_test
  msgb/msgb_test
  tlv/tlv_test
  write_queue/wqueue_test
  endian/endian_test
  prbs/prbs_test
  gsm23003/gsm23003_test
  gsm23236/gsm23236_test
  tdef/tdef_test
  sockaddr_str/sockaddr_str_test
  use_count/use_count_test
  context/context_test
  gsm0502/gsm0502_test
  dtx/dtx_gsm0503_test
  bitgen/bitgen_test
  gad/gad_test
  bsslap/bsslap_test
  bssmap_le/bssmap_le_test
  it_q/it_q_test
  time_cc/time_cc_test
  gsm48/rest_octets_test
  base64/base64_test
  iuup/iuup_test
  soft_uart/soft_uart_test
  rlp/rlp_test
  jhash/jhash_test
  timer/timer_test
  timer/clk_override_test
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

echo "[fr-tests] Summary: total=$total passed=$passed failed=$failed missing=$missing"
if [[ $failed -gt 0 ]]; then
  echo "[fr-tests] Failed tests:" >&2
  printf '  %s\n' "${failed_list[@]}" >&2
  exit 1
fi
if [[ $total -eq 0 ]]; then
  echo "[fr-tests] No tests executed (empty allowlist or all missing)." >&2
  exit 2
fi
exit 0
