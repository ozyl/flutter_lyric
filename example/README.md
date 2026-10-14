# Lyric Studio

A responsive, configuration-driven playground for `flutter_lyric`.

- **Two bundled songs:** Be What You Wanna Be and STAY (Explicit), both with
  word-timed lyrics and Chinese translations. Click the track information in
  the player to switch songs. Each selection starts at zero and keeps the
  current playing/paused state, timing preview and preset drafts. Loading
  temporarily disables song selection and playback; retry reloads the selected
  song if its audio or lyrics fail to load.
- STAY loads QQ Music's vocal-start hint from its bundled `.meta.json`, at
  00:11.438. All presets enable Canvas countdown dots by default. The Motion
  inspector has three controls: dot count, total fade duration and optional
  breathing duration. Breathing uses only time left over after the full fade;
  shorter gaps show no dots. A vocal-start hint lets credits between zero and
  vocals supply that time without changing their text or timestamps.
  Dots exclusively own playback focus while visible; the previous line becomes
  inactive. They share lyric scrolling and row motion, leaving no space when
  hidden. The LRC preview retains the same hint.
- **11 presets in one gallery:** Apple Music, Moss, Aurora, Cascade, Pulse,
  Editorial, Cinema, Neon, Letter, Terminal and Drift (浮游).
- Apple Music is the first gallery entry and is selected when Studio opens.
- Moss, Aurora, Apple Music, Cascade, Pulse, Cinema and Drift use the library's
  `LyricPresets` directly. Cascade settles in three steps; Pulse springs past its
  target; Drift drifts diagonally; Cinema dissolves through a focus pull.
- Apple Music shares the stage and inspector with every other preset. There is
  no separate demo route or laboratory group.
- The stage's timing selector switches between the original word timestamps and
  a plain LRC preview for every preset. The preview shares the player clock and
  leaves the original document intact. LRC uses the next line as its end; the
  final line highlights as a whole when no end is known.
- **17 line transitions:** basic fade/scale/slide/blur plus Rise, Paper, Spring,
  Orbit, Pendulum, Zoom, Step, Drift and Focus dissolve. Each has a motion
  description in the inspector and can be paired with any style. The dissolve
  preserves neighboring rows in lists and fully fades outgoing single entries.
- Complete presets use distinct combinations: Moss rises, Aurora sweeps in arcs,
  Editorial slides like a page, Neon zooms into focus, Letter sways, and Terminal
  advances in short steps. Apple Music retains its original motion.
- Each preset has an independent session draft, undo/redo history and reset.
  Dragging a slider is one undo step. Drafts are in memory, not saved to disk.
- Typography, layout/anchors, highlighting/motion and interaction are editable.
  Edits update the stage immediately. Row delays, wave motion, word lift, float
  period/stagger and clear-while-browsing are all in the shared motion inspector.
  Changing a scroll curve preserves its duration behavior.
- Each control explains its visible effect. Tap its code icon for the matching
  `LyricPreset` API field. Layout distinguishes rewrapping with active/inactive
  font sizes from keeping wraps measured at the active text style. The latter
  uses the active font size for all rows, inheriting the ordinary font size when
  no active font size is set.
- **Copy Dart configuration** stays at the bottom of every inspector tab.
  It copies the selected style's current draft as public `LyricPresets` /
  `LyricLineTransitions` code, including gallery-only styles and edits. The code
  preview is selectable and shows where to pass `lyricPreset` to `LyricView`.
  Loading lyrics, syncing the controller with audio, seeking in `onLineTap`,
  backgrounds and the example selection toolbar belong to the integrating app.
  Drafts disappear when the app closes, so copy configurations you want to keep.
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
- `demo_songs.dart`: song metadata and bundled lyric loaders; add songs here.
  `loadBundledLyrics` reads `<prefix>.qrc`, `<prefix>.trans.lrc` and
  `<prefix>.meta.json`, passing the saved `startTs` to `LyricDocument.vocalStart`.
  The metadata uses the downloader's format: `{"startTs": 11438}` (milliseconds),
  or `{"startTs": null}` when the provider has no hint. To add another downloaded
  song, bundle these three files and its audio under a common prefix, then add
  a `DemoSong` entry and loader to the catalog.
- `studio.dart`: adaptive shell, original comparison, focus and inspector sheet.
- `demo_presets.dart`: gallery metadata and complete `LyricPreset` configurations.
- `demo_line_transitions.dart`: names/descriptions for reusable library transitions.
- `studio_state.dart`: independent drafts and bounded undo/redo histories.
- `preset_gallery.dart`: one gallery with desktop cards and a mobile strip.
- `show_lyric.dart`: live stage, anchor guide and lyric selection overlays.
- `edit_preset.dart`: grouped configuration controls.
- `preset_help.dart`: effect descriptions and public API field references.
- `preset_export.dart`: standalone Dart configuration snippets for integration.
- `scroll_tuning.dart`: reversible retiming of fixed and custom animations.
- `playback_controls.dart`: seekable transport with loading/error states.
- `studio_preview.dart`: plain LRC preview synchronized with the original player.
- `just_audio_progress_source.dart`: frame-readable player position adapter.

The Motion inspector includes a countdown switch and three controls:
“小圆点数量”, “小圆点时长” and “小圆点呼吸时长”. Presets supply colors, sizes,
alignment and spacing. Changes participate in undo/redo and Dart export.
Plain LRC interludes need a blank timestamp marking silence; word-timed lyrics
can use their ends.

Run `flutter pub get`, then `flutter run -d macos` or `flutter run -d chrome`.
Run `flutter test` for preset/history, responsive layout and interaction tests.
Run `flutter test integration_test/playback_test.dart -d macos` to verify real
audio playback, pause, seeking and a minute of continuous lyric effect changes.
Run `flutter test integration_test/playback_start_test.dart -d macos` to check
eight starts/resumes for backwards lyric progress, including replay from zero.
This test plays the bundled audio through the current output device.
Run `flutter test integration_test/song_switch_test.dart -d macos` to check
both MP3s with the real decoder while switching in paused and playing states.
For web, start ChromeDriver on port 4444 and run:

```sh
flutter drive --driver=test_driver/integration_test.dart \
  --target=integration_test/song_switch_test.dart -d web-server \
  --browser-name=chrome --headless \
  --web-browser-flag=--autoplay-policy=no-user-gesture-required
```

Song changes stop and release the previous audio backend before loading the
selected asset. This avoids `just_audio_web` 0.4.16 reusing its cached first
playlist on repeated `setAsset` calls, including on GitHub Pages; see
[the upstream issue](https://github.com/ryanheise/just_audio/issues/1596).
The regression test checks decoded MP3 durations as well as the selected title
and playback state, so updating only the Dart-side source cannot make it pass.

The macOS example uses `just_audio_media_kit` with the audio-only libmpv bundle.
This avoids the AVPlayer `currentTime` call that blocked the main thread after
an audio output device disconnected. The `just_audio` API and lyric progress
adapter stay the same; Android, iOS and web retain their default backends.
The adapter holds the last displayed position when native clock corrections
arrive behind just_audio's predicted time, then follows the player again as soon
as it catches up. Lyrics and transport use that same position. Explicit seeks,
replays and track changes reset the held position, so backwards seeking still
works. Both player-event and discontinuity subscriptions are released when
controllers detach; the adapter does not run a separate playback clock.
Runtime audio errors and failed pause requests appear in the transport's retry
state. Restart the app after changing native audio dependencies; hot reload is
not enough.

The example needs a modern Flutter/Dart SDK for its player dependencies; the
library's own minimum remains Dart 2.12 / Flutter 2.0.
