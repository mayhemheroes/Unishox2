
unicode-fuzzer: unicode-fuzzer.c ../unishox2.c
	clang -g -fsanitize=fuzzer -DUNISHOX_API_WITH_OUTPUT_LEN=1 ../unishox2.c unicode-fuzzer.c -o unicode-fuzzer