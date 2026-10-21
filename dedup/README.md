# Dedup: perf and flame graph

Inside `node-alpha`, in `~/dedup`:

```bash
# Sample on-CPU stacks 999 times per second. v2 runs for only ~20 ms,
# so run it 300 times to get enough samples.
perf record -F 999 -g -- sh -c 'for i in $(seq 300); do ./v2_dedup; done'

# Keep only v2_dedup's samples (drop sh and seq), then draw the flame graph.
perf script --comms v2_dedup > out.perf
~/FlameGraph/stackcollapse-perf.pl out.perf > out.folded
~/FlameGraph/flamegraph.pl out.folded > v2_dedup.svg
```

Copy the SVG to the host and open it in a browser (run on the host):

```bash
lxc file pull node-alpha/root/dedup/v2_dedup.svg .
```
