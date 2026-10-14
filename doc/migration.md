# Migrating from 3.x to 4.0

4.0.0 is a major release with breaking API changes from 3.x. Replace old deep imports with:

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

## Intro and interlude countdown

All presets now enable countdown dots with colors and spacing adapted to their
style. Use `preset.copyWith(countdown: const LyricCountdown.none())` to disable
them. Dots own the view's playback focus while visible; controller active-line
indices and document entries remain unchanged.

Timing has three settings: `dotCount`, total `dotDuration` (default three
seconds), and optional `breathDuration`. Gaps shorter than `dotDuration` show
no dots. Breathing uses only the excess time before the complete fade.
`LyricCountdownMode`, `minimumGap`, `leadIn`, `showIntro`, `showInterludes` and
`extraDuration` have been removed. For the old per-second behavior, set
`dotDuration: Duration(seconds: dotCount)`; replace `extraDuration` with
`breathDuration`. A `vocalStart` hint lets intro credit time from zero to vocals
supply the countdown budget, but the intro must still fit the full fade.

For ordinary LRC, add a blank timestamp at the start of an interlude, or provide
`LyricLine.end` / complete word end times. Start-only nonempty lines do not
provide enough information to infer silence safely. No data migration is
required. See [countdown configuration](api.md#lyriccountdown).

## Compatibility

The library keeps the Dart 2.12 minimum, has no third-party runtime dependency, and uses Flutter 2-compatible syntax. Modern native paragraph disposal and floating-point color alpha are selected through a small capability adapter. Flutter 2's paint-only invalidation behavior is handled separately. The example's newer audio-player dependencies do not change the library minimum.

## Apple Music and Studio presets

Use `LyricView(controller: controller, preset: LyricPresets.appleMusic)` for new
Apple Music integrations. `AppleMusicLyricView` and `AppleMusicLyricStyle` remain
compatible wrappers; existing calls do not need to change.

Character Float now defaults to `LyricFloatMode.highlighted`: unhighlighted
graphemes stay still, and float eases in with each character's highlight.
Disabling highlighting also disables float in this mode. To retain the previous
whole-line behavior, pass `floatMode: LyricFloatMode.all` to `LyricWordEffects`,
or `characterFloatMode: LyricFloatMode.all` to `AppleMusicLyricStyle` (including
its `copyWith`). Word Pop settings and held lift heights are unchanged. Studio's
float mode selector supports both choices and includes the mode in copied code.

Long-line switching now reuses bounded glyph atlases at the view's device pixel
ratio for solid-color Character Float, preserving the configured motion and
timing. Engines without synchronous image handles, oversized glyph atlases,
partial highlight tails and custom gradients retain the paragraph renderer.
No application migration is required; see the [performance notes](apple_music_performance.md)
for benchmark scope and device verification.

Studio now uses one gallery and inspector for every preset. The separate Apple
Music route and Issue #41 laboratory entries have been removed. Choose Apple
Music in the gallery and use the stage timing menu to preview ordinary LRC.
`LyricPresets.cascade`, `pulse` and `drift` add reusable motion configurations.
Built-in presets now use distinct named line transitions. Cinema dissolves
through a focus pull; to keep its previous line
transition, use `LyricPresets.cinema.copyWith(lineTransition: const
LyricLineTransition())`.

Line transitions are independently reusable through `LyricLineTransitions`.
For example, `LyricPresets.aurora.copyWith(lineTransition:
LyricLineTransitions.spring)` keeps Aurora's colors and layout while changing
its line motion. `LyricLineTransitions.classic` restores the original dual-style
size transition for Moss or Aurora. Apple Music's transition stays unchanged.

`LyricLineTransitions.step` now uses a 12 px horizontal offset instead of an
18 px downward offset for inactive lines. This preserves the configured vertical
spacing around the active line. Its API, segment timing and durations are unchanged.
