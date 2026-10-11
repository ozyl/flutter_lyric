# Migrating from 3.x to 4.0

4.0 is a breaking API preview. Replace old deep imports with:

```dart
import 'package:flutter_lyric/flutter_lyric.dart';
```

## Main replacements

| 3.x | 4.0 |
| --- | --- |
| LyricStyle / LyricStyles | LyricPreset / LyricPresets |
| default1 / default2 / single | centered / leading / singleLine |
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

## Compatibility

The library keeps the Dart 2.12 minimum, has no third-party runtime dependency, and uses Flutter 2-compatible syntax. Modern native paragraph disposal and floating-point color alpha are selected through a small capability adapter. Flutter 2's paint-only invalidation behavior is handled separately. The example's newer audio-player dependencies do not change the library minimum.
