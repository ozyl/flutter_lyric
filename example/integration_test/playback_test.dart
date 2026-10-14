// @dart=3.8

import 'package:flutter/widgets.dart';
import 'package:flutter_lyric/flutter_lyric.dart';
import 'package:flutter_lyric_example/main.dart' as app;
import 'package:flutter_lyric_example/playback_controls.dart';
import 'package:flutter_lyric_example/preset_gallery.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('native playback advances lyrics and supports pause and seek', (
    tester,
  ) async {
    app.main();
    await tester.pump();
    PlaybackControls controls() =>
        tester.widget<PlaybackControls>(find.byType(PlaybackControls));
    Future<void> waitFor(bool Function() condition) async {
      final deadline = DateTime.now().add(const Duration(seconds: 20));
      while (!condition() && DateTime.now().isBefore(deadline)) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(condition(), isTrue);
    }

    await waitFor(() => !controls().loading);
    expect(controls().error, isNull);
    final controller = tester
        .widget<LyricView>(find.byType(LyricView))
        .controller;
    for (var cycle = 0; cycle < 3; cycle++) {
      final before = controller.position;
      controls().onPlay();
      await waitFor(
        () => controller.position > before + const Duration(seconds: 2),
      );
      controls().onPlay();
      await waitFor(() => !controls().playing);
      final paused = controller.position;
      await tester.pump(const Duration(milliseconds: 500));
      expect(
        (controller.position - paused).abs(),
        lessThan(const Duration(milliseconds: 100)),
      );
      final target = Duration(seconds: 20 * (cycle + 1));
      controls().onSeek(target);
      await waitFor(
        () => (controller.position - target).abs() < const Duration(seconds: 1),
      );
      expect(controller.activeLineIndex, isNotNull);
      expect(tester.takeException(), isNull);
    }
    final state = tester
        .widget<PresetGallery>(find.byType(PresetGallery))
        .state;
    final original = state.preset;
    controls().onPlay();
    for (final preset in [
      original.copyWith(
        lineTransition: const LyricLineTransition.effects([
          LyricLineEffect.fade(.5),
        ]),
      ),
      original.copyWith(
        lineTransition: const LyricLineTransition.effects([
          LyricLineEffect.slide(Offset(24, 8)),
          LyricLineEffect.fade(.5),
        ]),
      ),
      original.copyWith(
        lineTransition: const LyricLineTransition.effects([
          LyricLineEffect.blur(3),
        ]),
      ),
      LyricPresets.appleMusic,
    ]) {
      state.update(preset);
      final before = controller.position;
      final index = controller.activeLineIndex;
      await waitFor(
        () => controller.position > before + const Duration(seconds: 15),
      );
      expect(controller.activeLineIndex, isNot(index));
      expect(controls().error, isNull);
      expect(tester.takeException(), isNull);
    }
    controls().onPlay();
    await waitFor(() => !controls().playing);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
