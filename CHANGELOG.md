## [3.0.7]

### Fixed

* `LrcParser` now accepts colon-separated fractional timestamps (e.g. `[00:00:58]`) in addition to dot format (`[00:00.58]`), fixing Netease Cloud Music lyrics that mix both styles ([#42](https://github.com/ozyl/flutter_lyric/pull/42) by [HBWuChang](https://github.com/HBWuChang)).

### Added

* Unit tests for colon and dot timestamp parsing in `test/lyric_parse_test.dart`.

## [3.0.6]

### Fixed

* Fix regression in 3.0.5 where highlight and auto-scroll stopped working: only dispose `CurvedAnimation` on animation `completed`, not on `dismissed` ([#39](https://github.com/ozyl/flutter_lyric/issues/39)).

## [3.0.5]

### Fixed

* Fix animation lifecycle issues in scroll, highlight, and line-switch mixins: properly dispose `CurvedAnimation`, guard async callbacks with `mounted`, and correct `dispose` order to prevent exceptions when leaving and re-entering lyric pages ([#39](https://github.com/ozyl/flutter_lyric/issues/39)).

### Changed

* Enable strict inference and `type_annotate_public_apis` in `analysis_options.yaml`; add missing type annotations across public APIs for improved static analysis score.

## [3.0.4]

### Breaking changes

* **None.** Both updates are backward compatible for public API consumers.

### Behavior changes (non-breaking)

* **Active highlight vs. text opacity:** Gradients/highlights on the playing line are no longer tied to `activeStyle` text opacity. You can use a semi-transparent `activeStyle.color` for unplayed syllables while keeping full-strength highlight colors/gradients ([#41](https://github.com/ozyl/flutter_lyric/issues/41)). Existing apps that depended on highlight fading together with text opacity will see different visuals; adjust `activeStyle` / `activeHighlightGradient` (or related highlight settings) if needed.

### Added

* `LyricScrollAnimationConfig` and `LyricScrollAnimationBuilder` on `LyricStyle.scrollAnimationBuilder` — override scroll **duration** and **curve** per scroll distance (`offset` in pixels). When unset, behavior matches previous `scrollDuration` / `scrollDurations` / `scrollCurve` logic ([#41](https://github.com/ozyl/flutter_lyric/issues/41)).

### Fixed

* Decouple active highlight rendering from active text opacity: dedicated mask painters avoid per-frame text relayout while preserving fade behavior.

### Example

* Issue #41 demo presets in `example/lib/issue41_demo_style.dart` (gradient highlight + scroll animation curves).

## [3.0.3]
* fix: Skip exit animation on the first line switch to avoid unwanted transition
* feat: `enableSwitchAnimation` now also animates text color transitions for both main and translation lyrics [#40](https://github.com/ozyl/flutter_lyric/pull/40) by [HBWuChang](https://github.com/HBWuChang)
* perf: Optimize `LyricPainter` — cache style lookups, reduce redundant object creation, only rebuild TextSpan when color changes

## [3.0.2]
* feat: add FallbackParser to provide safe handling for unsupported lyric formats

## [3.0.1]
* feat: Changed style management—now pass styles via the `LyricView.style` parameter instead of using `LyricController.setStyle()`
* perf: Added `LyricStyle.compareTo()` for smarter/faster detection of when relayout or repaint is needed on style changes
* fix: In `LyricStyle.copyWith()`, renamed the parameter `crossAxisAlignment` to the correct `contentAlignment`
* breaking: Removed `LyricController.styleNotifier` and the `setStyle()` method
* fix: Fixed an issue when switching lyrics

## [3.0.0+1]
* update plugin config

## [3.0.0]
* breaking: Rebuilt `LyricView` and the scrolling/highlight mixins so everything is driven by a single `LyricController`
* feat: Added translation & word-by-word rendering, touch scrubbing, anchor selection, and tap callbacks
* feat: Extended `LyricStyle` with gradient highlights, fade ranges, and scroll-duration mapping for deeper customization
* docs: Refreshed the README with a 3.0.0 migration guide

## [2.0.4+6]
* Fix animation before first line starts
## [2.0.4+5]
* Avoid Warning messages
## [2.0.4+4]
* fix:position has error on init.
## [2.0.4+3]
* fix:position not work on init. has error,please use [2.0.4+4]
## [2.0.4+2]
* fix package not showing support for Android, iOS, Windows, Linux & macOS on pub.dev.
## [2.0.4+1]
* merged pull#18 [Remove redundant configuration. ](https://github.com/ozyl/flutter_lyric/pull/18)
## [2.0.4]
* [Support setting gradient direction](https://github.com/ozyl/flutter_lyric/issues/14)
## [2.0.3]
* add empty status builder
* fix size
## [2.0.2+4]
* fix:highlight NPE
## [2.0.2+3]
* fix:padding lead to overflow clipping
## [2.0.2+2]
* pub score
## [2.0.2+1]
* fix location always on last
## [2.0.2]
* highlight(enhanced&normal)
## [2.0.1+2~2.0.1+6]
* modify pub config
## [2.0.1+1]
* fix safari load failed
## [2.0.1]
* more smooth
## [2.0.0+1]
* docs: Update CHANGELOG.md,README.md
## [2.0.0]
* sliding inertia.custom UI,Parse
## [0.0.1~1.0.2]
* show lyric