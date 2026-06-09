#!/usr/bin/env bash
#
# Unishox2/mayhem/test.sh — behavioral round-trip known-answer oracle → CTRF.
#
# Strategy (anti-reward-hacking, §6.3):
#   For each test string we:
#     1. Compress to a temp file via "test_unishox2 -c <in> <out> [preset]"
#     2. Decompress back via "test_unishox2 -d <out> <rt> [preset]"
#     3. Assert the decompressed file content byte-matches the original string.
#   A neutered binary (exit(0)) never writes the output files → the comparison
#   fails immediately.  An identity-no-op decompressor that returns the
#   compressed bytes → bytes won't match either. Only a correct compress+decompress
#   round-trip can pass every case.
#
# We also spot-check the single-string CLI ("test_unishox2 <string>") which
# prints "Decompressed: <string>" — absent from a neutered binary.
set -uo pipefail
[ -n "${SOURCE_DATE_EPOCH:-}" ] || unset SOURCE_DATE_EPOCH
cd "$SRC"

# emit_ctrf <tool> <passed> <failed> [skipped] [pending] [other]
emit_ctrf() {
  local tool="$1" passed="$2" failed="$3" skipped="${4:-0}" pending="${5:-0}" other="${6:-0}"
  local tests=$(( passed + failed + skipped + pending + other ))
  cat > "${CTRF_REPORT:-$SRC/ctrf-report.json}" <<JSON
{
  "results": {
    "tool": { "name": "$tool" },
    "summary": {
      "tests": $tests,
      "passed": $passed,
      "failed": $failed,
      "pending": $pending,
      "skipped": $skipped,
      "other": $other
    }
  }
}
JSON
  printf 'CTRF {"results":{"tool":{"name":"%s"},"summary":{"tests":%d,"passed":%d,"failed":%d,"pending":%d,"skipped":%d,"other":%d}}}\n' \
    "$tool" "$tests" "$passed" "$failed" "$pending" "$skipped" "$other"
  [ "$failed" -eq 0 ]
}

BIN=/mayhem/test_unishox2
[ -x "$BIN" ] || { echo "missing $BIN — run mayhem/build.sh first" >&2; exit 2; }

passed=0; failed=0
TMPDIR_RT="$(mktemp -d)"
trap 'rm -rf "$TMPDIR_RT"' EXIT

# run_roundtrip <label> <string> [preset]
# Compress the string to a file, decompress it back, assert byte-equality.
run_roundtrip() {
  local label="$1" input="$2" preset="${3:-0}"
  local inf="$TMPDIR_RT/in_${label}.txt"
  local cmpf="$TMPDIR_RT/cmp_${label}.bin"
  local outf="$TMPDIR_RT/out_${label}.txt"

  printf '%s' "$input" > "$inf"

  # Compress
  if ! "$BIN" -c "$inf" "$cmpf" "$preset" >/dev/null 2>&1; then
    echo "FAIL $label: compress exited non-zero"
    failed=$((failed+1)); return
  fi

  # Must have produced a non-empty compressed file
  if [ ! -s "$cmpf" ]; then
    echo "FAIL $label: compressed output is empty (exit(0) neutering?)"
    failed=$((failed+1)); return
  fi

  # Decompress
  if ! "$BIN" -d "$cmpf" "$outf" "$preset" >/dev/null 2>&1; then
    echo "FAIL $label: decompress exited non-zero"
    failed=$((failed+1)); return
  fi

  # Assert content match
  local got
  got="$(cat "$outf" 2>/dev/null || true)"
  if [ "$got" = "$input" ]; then
    echo "PASS $label"
    passed=$((passed+1))
  else
    echo "FAIL $label: expected '$input', got '$got'"
    failed=$((failed+1))
  fi
}

# run_cli_check <label> <string>
# Uses the single-string CLI mode which prints "Decompressed: <string>" to stdout.
# Neutered binary never prints that line.
run_cli_check() {
  local label="$1" input="$2"
  local out
  out="$("$BIN" "$input" 2>/dev/null || true)"
  # The CLI mode prints exactly: "Decompressed: <string>" (among other lines)
  if printf '%s\n' "$out" | grep -qF "Decompressed: $input"; then
    echo "PASS $label (cli)"
    passed=$((passed+1))
  else
    echo "FAIL $label (cli): 'Decompressed: $input' not found in output"
    failed=$((failed+1))
  fi
}

# ── Round-trip tests across several presets ──────────────────────────────────
# Preset 0 (default)
run_roundtrip "basic_hello_p0"   "Hello World"                                          0
run_roundtrip "pangram_p0"       "The quick brown fox jumped over the lazy dog"          0
run_roundtrip "upper_p0"         "HELLO WORLD"                                           0
run_roundtrip "mixed_num_p0"     "Hello123 World456"                                     0

# Preset 1 (alpha only)
run_roundtrip "alpha_only_p1"    "Hello"                                                 1
run_roundtrip "upper_p1"         "HELLO WORLD"                                           1

# Preset 2 (alpha+num)
run_roundtrip "alphanum_p2"      "Hello World 2024"                                      2

# Preset 6 (favor-dict)
run_roundtrip "dict_p6"          "the quick brown fox"                                   6

# Preset 12 (URL)
run_roundtrip "url_p12"          "https://example.com/path?q=1"                         12

# Preset 13 (JSON)
run_roundtrip "json_p13"         '{"key":"value","n":42}'                               13

# ── CLI spot-checks (behavioral: output must contain the decompressed string) ─
run_cli_check "cli_hello"        "Hello"
run_cli_check "cli_world"        "World"

emit_ctrf "unishox2-roundtrip-behavioral" "$passed" "$failed"
