#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "../unishox2.h"

int LLVMFuzzerTestOneInput(const uint8_t *Data, size_t Size)
{
    if (Size > 2) {
        char* input = (char*) malloc(Size - 1);
        memcpy(input, Data + 1, Size - 1);
        char* output = (char*) malloc(Size * 16);
        
        switch (Data[0] % 2) {
            case 0:
                unishox2_compress(input, Size - 1, output, Size * 8, USX_HCODES_DFLT, USX_HCODE_LENS_DFLT, USX_FREQ_SEQ_TXT, USX_TEMPLATES);
                break;
            case 1:
                // unishox2_decompress_simple(input, Size - 1, output);
                unishox2_decompress(input, Size - 1, output, Size * 8, USX_HCODES_DFLT, USX_HCODE_LENS_DFLT, USX_FREQ_SEQ_TXT, USX_TEMPLATES);
                break;
            // case 2:
            //     unishox2_decompress_simple(input, Size - 1, output);
            //     break;
            // case 3:
            //     unishox2_decompress_simple(input, Size - 1, output);
            //     break;
        }

        free(input);
        free(output);
    }
  return 0;
}