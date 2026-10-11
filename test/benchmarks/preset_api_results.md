# Preset API refactor measurements

2026-10-11, local arm64 macOS host, Flutter 3.44.8 test engine.
Baseline: `576e6a3`. Candidate: `codex/lyric-preset-api` working tree.

Both revisions use matching text styles, 400 × 600 viewports, spacing and
highlight settings. The load fixture uses the old default2 typography with zero
horizontal padding and a 100px main-text anchor. The baseline top padding is
100px so its old clamp permits the same initial alignment. The scroll fixture
uses old default1 typography/spacing with zero padding and no highlighting.
Native disposal and model generation are outside timed sections.

Commands, run sequentially in each checkout:

```sh
flutter test --no-pub test/benchmarks/lyric_load_benchmark.dart \
  test/benchmarks/lyric_scroll_benchmark.dart --reporter expanded --concurrency=1
```

Load: 10 warm-ups, median of 5 samples. Scroll: 300 warm-up frames, median of
5 batches of 300 picture recordings. Results from the final baseline run and
final candidate run after removing redundant TextSpan assignments:

| Entries | Baseline load, ms | Candidate load, ms | Baseline record, µs/frame | Candidate record, µs/frame |
| --- | ---: | ---: | ---: | ---: |
| 100 | 6.55 | 6.87 | 24.9 | 23.3 |
| 1,000 | 45.34 | 46.70 | 12.7 | 14.5 |
| 5,000 | 237.54 | 242.23 | 12.6 | 12.3 |

These are CPU layout/picture-recording measurements, not GPU frame times. They
show the same scaling behavior: initial exact layout grows with the document;
painting visits only visible entries. Small differences and JIT/GC variation
remain, so these measurements do not establish a speedup or a universal
no-regression guarantee. Earlier runs with only two load warm-ups varied more
(the 100-entry candidate ranged from 6.37 to 7.76ms).

The new active-only mode measures one entry instead of the full document;
shared-controller sampling and paragraph reuse are covered by regression tests.
The existing compositing and profile-frame benchmark entry points have also
been migrated, but their GPU/profile results have not been rerun for this API
refactor. Older result files describe their original commits, not 4.0.
