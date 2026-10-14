// @dart=3.8

import 'package:flutter/widgets.dart';
import 'package:flutter_lyric/flutter_lyric.dart';
import 'package:flutter_lyric_example/just_audio_progress_source.dart';
import 'package:flutter_lyric_example/main.dart' as app;
import 'package:flutter_lyric_example/playback_controls.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('starting and resuming playback never rewinds lyrics', (
    tester,
  ) async {
    app.main();
    await tester.pump();
    PlaybackControls controls() =>
        tester.widget<PlaybackControls>(find.byType(PlaybackControls));
    Future<void> waitFor(bool Function() condition) async {
      final deadline = DateTime.now().add(const Duration(seconds: 20));
      while (!condition() && DateTime.now().isBefore(deadline)) {
        await tester.pump(const Duration(milliseconds: 16));
      }
      expect(condition(), isTrue);
    }

    await waitFor(() => !controls().loading);
    expect(controls().error, isNull);
    final controller = tester
        .widget<LyricView>(find.byType(LyricView))
        .controller;
    final player =
        (controller.progressSource as JustAudioProgressSource).player;
    final rewinds = <String>[];
    for (var cycle = 0; cycle < 8; cycle++) {
      if (cycle.isEven) {
        controls().onSeek(Duration.zero);
        await waitFor(
          () => controller.position < const Duration(milliseconds: 100),
        );
        await tester.pump(const Duration(milliseconds: 200));
      }
      var previous = controller.position;
      final before = previous;
      void recordPosition() {
        final current = controller.position;
        if (current < previous) {
          rewinds.add(
            'cycle $cycle: $previous -> $current; '
            'native ${player.playbackEvent.updatePosition}; '
            '${player.processingState}',
          );
        }
        previous = current;
      }

      controller.addListener(recordPosition);
      controls().onPlay();
      await waitFor(() => controls().playing);
      final deadline = DateTime.now().add(const Duration(seconds: 2));
      while (DateTime.now().isBefore(deadline)) {
        await tester.pump(const Duration(milliseconds: 16));
      }
      expect(
        controller.position,
        greaterThan(before + const Duration(seconds: 1)),
      );
      controls().onPlay();
      await waitFor(() => !controls().playing);
      await tester.pump(const Duration(milliseconds: 200));
      controller.removeListener(recordPosition);
      expect(controls().error, isNull);
      expect(tester.takeException(), isNull);
    }
    await tester.pumpWidget(const SizedBox.shrink());
    expect(rewinds, isEmpty, reason: rewinds.join('\n'));
  });
}
