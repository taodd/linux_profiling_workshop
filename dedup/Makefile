# -fno-omit-frame-pointer lets perf -g walk the user stack.
CFLAGS = -O2 -g -fno-omit-frame-pointer -Wall -Wno-unused-result

all: v1_dedup v2_dedup v3_dedup

clean:
	rm -f v1_dedup v2_dedup v3_dedup v1.bin v2.bin v3.bin perf.data* out.perf out.folded
