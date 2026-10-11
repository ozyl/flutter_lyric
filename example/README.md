# Lyric Studio

A responsive, configuration-driven playground for `flutter_lyric`.

- **8 styles:** Moss, Aurora, Editorial, Cinema, Neon, Letter, Terminal and Float.
- Moss, Aurora and Cinema use `LyricPresets.moss`, `aurora` and `cinema`
  directly; their styles are shared with the library.
- **7 experiments:** the original Issue #41 translucent text / gradient preset
  and all six custom scroll curves, with their distance-based durations intact.
- Each preset has an independent session draft, undo/redo history and reset.
  Dragging a slider is one undo step. Drafts are in memory, not saved to disk.
- Typography, layout/anchors, highlighting/motion and interaction are editable.
  Edits update the stage immediately. Retiming an experiment preserves its
  original distance resolver; changing a curve preserves its duration behavior.
- Wide desktops use a gallery, stage and inspector. Tablets use the gallery and
  stage with a bottom-sheet inspector. Phones use a horizontal gallery and a
  draggable inspector that resizes the live stage above it; short landscape
  windows scroll to retain usable controls.
- Original comparison shares one playback controller. It appears side by side
  when the stage has at least 720 logical pixels, otherwise as a full-stage A/B
  toggle. Focus mode expands the stage. The anchor guide visualizes positioning.
- Space toggles playback; Cmd/Ctrl+Z undoes; Shift+Cmd/Ctrl+Z redoes; Escape exits
  focus mode. Lyrics support seeking and returning to playback follow.

## Structure

- `main.dart`: audio lifecycle, loading/retry, seeking and application theme.
- `studio.dart`: adaptive shell, original comparison, focus and inspector sheet.
- `demo_presets.dart`: gallery metadata and complete `LyricPreset` configurations.
- `studio_state.dart`: independent drafts and bounded undo/redo histories.
- `preset_gallery.dart`: desktop cards, mobile strip and experiment filtering.
- `show_lyric.dart`: live stage, anchor guide and lyric selection overlays.
- `edit_preset.dart`: grouped configuration controls.
- `scroll_tuning.dart`: reversible retiming of fixed and custom animations.
- `playback_controls.dart`: seekable transport with loading/error states.
- `issue41_demo_preset.dart`: regression presets with a fixed baseline, independent of built-in styles.
- `just_audio_progress_source.dart`: frame-readable player position adapter.

Run `flutter pub get`, then `flutter run -d macos` or `flutter run -d chrome`.
Run `flutter test` for preset/history, responsive layout and interaction tests.
The example needs a modern Flutter/Dart SDK for its player dependencies; the
library's own minimum remains Dart 2.12 / Flutter 2.0.
