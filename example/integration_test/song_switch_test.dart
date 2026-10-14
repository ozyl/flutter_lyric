// @dart=3.8

import 'package:flutter/widgets.dart';
import 'package:flutter_lyric_example/demo_songs.dart';
import 'package:flutter_lyric_example/main.dart' as app;
import 'package:flutter_lyric_example/playback_controls.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('switching songs replaces the decoded audio on the real backend', (
    tester,
  ) async {
    app.main();
    await tester.pump();
    PlaybackControls controls() =>
        tester.widget<PlaybackControls>(find.byType(PlaybackControls));
    Future<void> waitFor(bool Function() condition) async {
      await tester.pump();
      final deadline = DateTime.now().add(const Duration(seconds: 20));
      while (!condition() && DateTime.now().isBefore(deadline)) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(condition(), isTrue);
      expect(controls().error, isNull);
    }

    // Durations come from the two bundled MP3 files, not Dart source metadata.
    // A fake player cannot catch the web backend retaining the first MP3.
    void expectAudio(DemoSong song) {
      expect(controls().song.id, song.id);
      expect(
        controls().duration.inMilliseconds,
        closeTo(song == stay ? 141806 : 211920, 1500),
        reason: 'The decoder must load ${song.audioAsset}.',
      );
    }

    await waitFor(() => !controls().loading);
    expectAudio(beWhatYouWannaBe);

    Future<void> select(DemoSong song, {required bool playing}) async {
      await tester.tap(find.byKey(const ValueKey('song-selector')));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.tap(find.byKey(ValueKey('song-${song.id}')));
      await waitFor(() => !controls().loading);
      expectAudio(song);
      expect(controls().position, lessThan(const Duration(seconds: 1)));
      await waitFor(() => controls().playing == playing);
      if (playing) {
        await waitFor(() => controls().position > const Duration(seconds: 1));
      }
    }

    await select(stay, playing: false);
    controls().onPlay();
    await waitFor(() => controls().position > const Duration(seconds: 1));
    await select(beWhatYouWannaBe, playing: true);
    await select(stay, playing: true);
    controls().onPlay();
    await waitFor(() => !controls().playing);
    await select(beWhatYouWannaBe, playing: false);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
