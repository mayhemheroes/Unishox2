#!/usr/bin/env bash
#
# Unishox2/mayhem/build.sh — build the decompression libFuzzer harness (+ standalone reproducer)
# and the project's own round-trip known-answer test program.
#
# Unishox2 is a single-TU C string compressor (unishox2.c + unishox2.h). The fuzz target is the
# DECOMPRESSOR (unishox2_decompress) on attacker-controlled bytes. The harness and the project are
# both compiled with $SANITIZER_FLAGS so ASan+UBSan instrument the decode path we are fuzzing.
#
# The whole API is built with -DUNISHOX_API_WITH_OUTPUT_LEN=1 (the olen variant): the harness passes
# an output-length bound to unishox2_decompress (matching upstream afl_fuzz/test_fuzz.c), and the
# test program's bounds-overflow checks only run in this mode.
set -euo pipefail

# clang rejects SOURCE_DATE_EPOCH='' (empty) — must be unset or a valid integer.
[ -n "${SOURCE_DATE_EPOCH:-}" ] || unset SOURCE_DATE_EPOCH

# Build knobs from the env (overridable). SANITIZER_FLAGS uses `=` so an explicit empty
# --build-arg SANITIZER_FLAGS= builds with NO sanitizers (natural crash, no ASan report).
: "${SANITIZER_FLAGS=-fsanitize=address,undefined -fno-sanitize-recover=all -fno-omit-frame-pointer -g}"
: "${DEBUG_FLAGS:=-g -gdwarf-3}"
: "${CC:=clang}" ; : "${LIB_FUZZING_ENGINE:=-fsanitize=fuzzer}" ; : "${MAYHEM_JOBS:=$(nproc)}"
export SANITIZER_FLAGS DEBUG_FLAGS CC LIB_FUZZING_ENGINE MAYHEM_JOBS

cd "$SRC"

OLEN=-DUNISHOX_API_WITH_OUTPUT_LEN=1
CMN="-std=c99 -O2 -I. $OLEN"

# 1) libFuzzer target: harness + the (sanitized) library compiled together so the decode path
#    being fuzzed is instrumented.
$CC $SANITIZER_FLAGS $DEBUG_FLAGS $LIB_FUZZING_ENGINE $CMN \
    mayhem/fuzz_decompress.c unishox2.c \
    -o /mayhem/unishox2-decompress-fuzz

# 2) Standalone (non-fuzzer) reproducer: same harness + LLVM's run-once driver, no libFuzzer
#    runtime — takes one input file, runs LLVMFuzzerTestOneInput once, crashes naturally.
$CC $SANITIZER_FLAGS $DEBUG_FLAGS $CMN \
    "$STANDALONE_FUZZ_MAIN" mayhem/fuzz_decompress.c unishox2.c \
    -o /mayhem/unishox2-decompress-fuzz-standalone

# 3) The project's OWN round-trip known-answer test program, built with NORMAL flags (no fuzz
#    sanitizers) so mayhem/test.sh stays an honest functional oracle. test_unishox2.c with no
#    -c/-d/-g args runs run_unit_tests(): it compresses each known string, decompresses it, and
#    asserts the result byte-matches the original (plus overflow/terminator checks under OLEN).
#    Built with the olen API so the overflow checks run; iterate over presets in test.sh.
"$CC" $CMN -o /mayhem/test_unishox2 unishox2.c test_unishox2.c

echo "build.sh: built unishox2-decompress-fuzz, -standalone, and test_unishox2"
