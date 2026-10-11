# flutter_lyric example

The audio player demo connects one `LyricController` to three independent lyric
views. Open the settings button in a view to switch an entire `LyricPreset` or
adjust its typography, alignment, anchors, display mode and interaction rules.

- `main.dart`: shared playback/controller and application-owned seeking.
- `just_audio_progress_source.dart`: frame-readable player position adapter.
- `show_lyric.dart`: view-local preset selection and selection overlay builders.
- `edit_preset.dart`: immutable `copyWith` adjustments, including nullable clears.
- `issue41_demo_preset.dart`: translucent active text, gradient highlighting and
  custom scroll curves for visual regression checks.

Run `flutter pub get` and `flutter run` from this directory. The example uses a
modern Flutter/Dart SDK because of the player dependencies; the library's own
minimum remains Dart 2.12 / Flutter 2.0.
