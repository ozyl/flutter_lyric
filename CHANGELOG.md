## [4.0.0]

This major release changes the public API from 3.x. See the [migration guide](doc/migration.md) and [API reference](doc/api.md) before upgrading.

### Breaking changes

* Replace `LyricStyle` / `LyricStyles` with immutable `LyricPreset` / `LyricPresets`, combining display mode, typography, layout, effects, animation, interaction policies and presentation builders. Configure views with `preset` instead of `style`; use explicit `.fraction()` / `.pixels()` units for anchors and edge fades.
* Rename controller methods to `load`, `loadDocument` and `setPosition`. Replace writable playback notifiers with an atomic, read-only `LyricPlaybackState` and `activeLineIndexListenable`; active lines and indices are nullable before the first lyric and when no lyrics are loaded.
* Replace `LyricModel` with immutable `LyricDocument`, `idTags` with `tags`, and integer offsets with `Duration`. Document offsets and controller `timeOffset` are applied separately. Rename the parsing API to `LyricDocument.parse` / `LyricParser.autoDetect` and custom parser methods to `canParse` / `parse`.
* Move tap and selection callbacks to each `LyricView`. Applications handle seeking through `onLineTap` and its offset-corrected `seekPosition`; the library does not change playback on tap. Replace the old selection widgets with preset builders and remove the public event bus, mutable selection notifiers and rendering/layout mixins.
* Size `LyricView` through parent constraints such as `SizedBox` or `Expanded` instead of view `width` / `height` parameters. Import public APIs from `package:flutter_lyric/flutter_lyric.dart`; the old `core/`, `widgets/`, `render/` and `utils/` paths are removed.

### Added

* `LyricProgressSource` for replaceable, player-owned progress, with one subscription and one frame sampler per controller. Advancing playback is sampled on each display frame while an attached view has `TickerMode` enabled and the app is in the foreground; pause, seek and other source events still update state without frame sampling. Binding a source disables manual `setPosition` calls.
* Multiple views per controller with independent scrolling, selection and follow state. Target `resumeFollow` / `scrollToLine` commands with `viewId`, or broadcast them to all attached views.
* Moss, Aurora and Cinema as const, customizable built-in presets, with Aurora as the default, plus `LyricPresetScope` for subtree defaults. These replace 3.x's `default1`, `default2` and `single`; earlier 4.0 preview names `leading`, `centered` and `singleLine` are also removed without aliases.
* Full active-translation typography, explicit anchor targets, and independent selection-snap and follow-resume policies. Selection builders receive viewport geometry and actions for their own view.

### Changed

* Use native Flutter scrolling around a Canvas viewport. Reuse text paragraphs, cached line metrics and edge-fade shaders, and paint only visible entries to reduce scrolling, repaint and compositing work.
* Defer active-text layout, highlight masks, row metrics and word bounds until first use, retaining exact normal and translation heights for scrolling. Active-line mode lays out only the current entry.
* Rebuild the example as responsive Lyric Studio with eight styles, seven regression/scroll experiments, live preset editing, per-preset drafts, undo/redo, original comparison and playback controls. The gallery shares the three library presets and keeps the Issue #41 fixture independent of their styling.
* Retain the Dart 2.12 / Flutter 2.0 library minimum and remove the unused `plugin_platform_interface` runtime dependency and incompatible lint dependency. Add minimum/modern Flutter CI checks, API and migration documentation, and playback, interaction, layout and pixel regression tests.

### Fixed

* Compose active text and highlight colors through a single neutral glyph mask to prevent colored fringes and thickened antialiased edges, preserving independent highlight opacity and line-switch animations ([#41](https://github.com/ozyl/flutter_lyric/issues/41)).
* Smooth trailing highlight fades at word and line endings, including wrapped lyrics and fractional positions.
* Restore highlight-mask layout after text-opacity changes, preventing missing or incorrectly rendered active and exiting text.
* Prevent lyric taps from leaving automatic scrolling stuck; resume following according to the view's interaction policy.

## [3.0.8]

### Added

* `YrcParser` for Netease Cloud Music word-by-word `.yrc` lyrics (`(start,dur,0)text`) and JSON credit headers ([#43](https://github.com/ozyl/flutter_lyric/issues/43)).

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
