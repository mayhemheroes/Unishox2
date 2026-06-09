/*
 * mayhem/fuzz_decompress.c — libFuzzer harness for Unishox2 decompression.
 *
 * The decompressor runs on attacker-controlled bytes (a compressed blob received
 * over the wire / from a file), so unishox2_decompress() is the bug-finding target:
 * we feed the raw fuzz input straight in as a "compressed" buffer and let ASan/UBSan
 * catch any out-of-bounds read/write or UB in the decode path. The output buffer is
 * sized generously relative to the input cap; the output-len API (olen) is used so the
 * decompressor is told the bound (matching the repo's own afl_fuzz/test_fuzz.c harness).
 *
 * Built with -DUNISHOX_API_WITH_OUTPUT_LEN=1 so unishox2_decompress takes the olen arg.
 */
#include <stdint.h>
#include <stddef.h>
#include "../unishox2.h"

int LLVMFuzzerTestOneInput(const uint8_t *buf, size_t len) {
  /* Cap input so the worst-case expansion fits the fixed output buffer below.
     Unishox2 can expand a tiny compressed blob into a much larger string, so keep
     a comfortable ratio between the input cap and the output size. */
  if (len > 4096)
    len = 4096;

  static char out[16 * 65536]; /* 1 MiB output scratch */
  unishox2_decompress((const char *)buf, (int)len, out, (int)sizeof(out),
                      USX_HCODES_DFLT, USX_HCODE_LENS_DFLT,
                      USX_FREQ_SEQ_TXT, USX_TEMPLATES);
  return 0;
}
