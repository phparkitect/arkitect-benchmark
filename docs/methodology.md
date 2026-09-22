# How the version history is measured

The question is whether a release is slower than the one before it, so what matters is the *difference* between versions, not their absolute times.

## Why absolute seconds are not compared

CI machines differ from one another: across runs, the same unchanged release has measured anywhere between 21.8s and 35.5s. The seconds in the table only show scale. Comparisons are always made between versions timed in the same job.

## Why the versions are interleaved

A shared CI machine also changes speed *during* a job. The benchmark used to time each version's repetitions back to back, which handed that drift to whichever version happened to be running: over five runs, the unchanged 1.0.0 release came out anywhere from 12% faster to 8% slower than 1.3.0.

So the versions are timed in rounds instead. Every round runs each version once, in a fresh random order, after one untimed warmup run per version. Each version is compared with the baseline (the latest release) within each round, where both timings came from the same few minutes on the same machine.

## When a difference is reported

Each round gives one difference from the baseline. The table shows the median of those differences only if enough rounds agree on its direction that a coin flip would manage it less than 5% of the time:

| Rounds | Must agree |
|---|---|
| 5 (default) | 5 |
| 8 | 7 |
| 10 | 9 |

It also has to be at least 2%. Rounds in one run share that run's machine, so they can agree on a difference the next run does not reproduce. Over the first three interleaved runs (75 rounds), a single round differed from the baseline by a median of 1.2 points and by more than 3 points one time in ten, but the median for the same version moved by up to 2 points from one run to the next: 1.3.0 came out at −0.4%, +0.3% and −1.3%.

Otherwise the cell shows `≈`. More rounds tolerate more disagreement, so they catch smaller differences within a run; the 2% floor stays, since more rounds do not remove the run's own offset. Each round costs about 3 minutes of CI time.

## What is timed

`phparkitect check` over `symfony/src` at a pinned tag, with the four rules in [`arkitect.php`](../arkitect.php), from process start to exit. The cross-tool comparison is separate and documented in [`competitors/`](../competitors/README.md).
