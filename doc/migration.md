# Migrating to 4.x

## Upgrading from 4.0 to 4.1

4.1.0 adds public APIs while retaining the published 4.0 constructors, methods
and preset names. The library minimum remains Dart 2.12 / Flutter 2.0.

All presets now enable Canvas countdown dots before vocals and between known
lyric gaps. Dots own the view's playback focus while visible; controller
active-line indices and document entries remain unchanged. To keep the 4.0
presentation without countdowns:

```dart
final preset = LyricPresets.aurora.copyWith(
  countdown: const LyricCountdown.none(),
  lineTransition: LyricLineTransitions.classic,
);
```

`LyricLineTransitions.classic` also restores the 4.0 size transition for Moss
and Cinema. Otherwise these presets use distinct trajectories. Layout remains
dual-style for these three presets, and Aurora remains the library default.
Studio now starts with Apple Music as its first gallery entry.

Countdown timing uses `dotCount`, total `dotDuration` (default three seconds),
and optional `breathDuration`. Gaps shorter than `dotDuration` show no dots;
breathing uses only excess time before the complete fade. For ordinary LRC,
add a blank timestamp at the start of an interlude, or provide `LyricLine.end`
/ complete word end times. Start-only nonempty lines cannot identify silence.
An optional `vocalStart` hint lets credit time from zero to vocals supply the
intro countdown budget without changing lyric entries or word timestamps.
See [countdown configuration](api.md#lyriccountdown).

Use `LyricView(controller: controller, preset: LyricPresets.appleMusic)` for
Apple Music-style motion. `AppleMusicLyricView` and `AppleMusicLyricStyle` are
new convenience wrappers around the same renderer. Character Float defaults
to `LyricFloatMode.highlighted`: unhighlighted graphemes stay still, and float
eases in with each character's highlight. Disabling highlighting also disables
float in this mode. Use `LyricWordEffects(floatMode: LyricFloatMode.all)` or
`AppleMusicLyricStyle(characterFloatMode: LyricFloatMode.all)` to float all text.
Word Pop independently controls the held lift height. Browsing stays crisp by
default; set `distanceBlur.whenBrowsing` / `blurWhenBrowsing` to true to retain
blur during browsing.

`cascade`, `pulse` and `drift` provide additional presets. Line transitions are
independently reusable; for example, `LyricPresets.aurora.copyWith(
lineTransition: LyricLineTransitions.spring)` keeps its colors and layout while
changing line motion. Studio shares the gallery, inspector and timing menu
across all presets, and exports edits as public Dart configuration.

Long-line switching reuses bounded glyph atlases at the view's device pixel
ratio for solid-color Character Float. Unsupported engines, oversized atlases,
partial highlight tails and custom gradients use the paragraph renderer. No
application migration is required; see the [performance notes](apple_music_performance.md).

## Upgrading from 3.x to 4.x

4.0 introduced breaking API changes from 3.x. Replace old deep imports with:

```dart
import 'package:flutter_lyric/flutter_lyric.dart';
```

## Main replacements

| 3.x | 4.0 |
| --- | --- |
| LyricStyle / LyricStyles | LyricPreset / LyricPresets |
| default1 / default2 / single | aurora / moss / cinema |
| LyricView(style: ...) | LyricView(preset: ...) |
| View width / height | SizedBox, Expanded or parent constraints |
| loadLyric / loadLyricModel | load / loadDocument |
| translationLyric on controller.loadLyric | translation on controller.load |
| setProgress | setPosition |
| LyricModel / idTags / int offset | LyricDocument / tags / Duration offset |
| LyricParse.parse | LyricDocument.parse or LyricParser.autoDetect |
| parser.isMatch / parseRaw | parser.canParse / parse |
| activeIndexNotifiter | activeLineIndexListenable; nullable before the first lyric |
| progressNotifier.value | position, or listen to the controller's atomic value |
| lyricOffset | timeOffset (Duration); document.offset is applied separately |
| setOnTapLineCallback | LyricView.onLineTap(LyricLineDetails) |
| stopSelection / resumeActiveLine event | controller.resumeFollow(viewId: ...) |
| shared selected-index / rect notifiers | per-view onSelectionChanged and preset builders |
| event registration, rendering/layout mixins | internal implementation; no public event bus |

A controller can now drive several views. It no longer owns one global selection or callback. Move callbacks to the corresponding `LyricView`; use `viewId` when targeting one view.

## Built-in style names

The earlier 4.0 preview names `centered`, `leading` and `singleLine` have been
removed, without aliases. Replace them with `aurora`, `moss` and `cinema`,
respectively. The new presets use the corresponding Lyric Studio designs,
including larger typography, updated colors, spacing and animation. Views with
no explicit preset or scope now use Aurora. Each preset remains a `const` value
and supports `copyWith`; the neutral `LyricPreset()` defaults are unchanged.

## Preset fields

| Previous setting | Replacement |
| --- | --- |
| activeStyle | activeTextStyle |
| translationStyle | translationTextStyle |
| translationActiveColor | activeTranslationTextStyle: TextStyle(color: ...) |
| selectedColor / selectedTranslationColor | selectedTextColor / selectedTranslationTextColor |
| lineTextAlign | textAlign |
| CrossAxisAlignment contentAlignment | LyricContentAlignment (start / center / end) |
| contentPadding / lineGap / translationLineGap | padding / lineSpacing / translationSpacing |
| activeAnchorPosition + activeAlignment | LyricAnchor.fraction/pixels(..., target: ...) |
| selectionAnchorPosition + selectionAlignment | selectionAnchor: LyricAnchor(...) |
| activeHighlightColor / gradient / extraFadeWidth | one LyricHighlight.solid / gradient value, tailFadeWidth |
| fadeRange | LyricEdgeFade.pixels / fraction / none |
| scrollDuration / durations / curve / builder | LyricScrollAnimation.fixed / byDistance / custom / none |
| switch durations / curves / enableSwitchAnimation | LyricLineTransition / none |
| activeLineOnly | displayMode: LyricDisplayMode.activeLine |
| disableTouchEvent | interactive (inverse) |
| selectionAutoResumeDuration | selectionSnapDelay |
| activeAutoResumeDuration | resumeDelay; null disables automatic resume |
| selectionAutoResumeMode | selectionSnapMode; snap and follow-resume are now independent |

There is no 0…1-versus-pixels heuristic. Choose `.fraction()` or `.pixels()` explicitly, even for 1 pixel. Anchors align the center of main text, translation or the complete entry. Large vertical padding used to position the first line is no longer needed.

Nullable `copyWith` values keep their old setting. Use the matching `clear...` flag to clear them; use `.none()` for effects. Presets compare structurally and retain builder function identity.

## Selection controls

The old selected-background/progress widgets are replaced by `selectionBackgroundBuilder` and `selectionForegroundBuilder` on the preset. Their callbacks travel with the preset when switching. Application seeking stays in `LyricView.onLineTap`.

Use `details.line.seekPosition`, not `line.start`, to seek. It already removes both lyric offsets. `details.onTap` forwards the application's handler and applies `resumeOnTap`; `details.resumeFollow` affects just this view. See [the example builders](../example/lib/show_lyric.dart).

Do not cache builder actions across view/document replacement. Old actions are deliberately inert. Empty-state content is provided by `preset.emptyBuilder`.

## SDK compatibility

The library keeps the Dart 2.12 minimum, has no third-party runtime dependency,
and uses Flutter 2-compatible syntax. Modern native paragraph disposal and
floating-point color alpha are selected through a capability adapter. Flutter
2's paint-only invalidation behavior is handled separately. The example needs
Dart 3.8.1 or later for its audio-player dependencies; this does not change the
library minimum.
