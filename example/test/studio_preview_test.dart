// @dart=3.8

import 'package:flutter/material.dart';
import 'package:flutter_lyric/flutter_lyric.dart';
import 'package:flutter_lyric_example/demo_presets.dart';
import 'package:flutter_lyric_example/edit_preset.dart';
import 'package:flutter_lyric_example/preset_gallery.dart';
import 'package:flutter_lyric_example/studio.dart';
import 'package:flutter_lyric_example/studio_preview.dart';
import 'package:flutter_lyric_example/studio_state.dart';
import 'package:flutter_lyric_example/studio_theme.dart';
import 'package:flutter_test/flutter_test.dart';

LyricDocument document() => LyricDocument(
  offset: const Duration(milliseconds: 200),
  tags: const {'ti': 'Preview'},
  lines: List.generate(
    12,
    (i) => LyricLine(
      start: Duration(seconds: i * 4),
      end: Duration(seconds: i * 4 + 3),
      text: 'Hello music $i',
      translation: '歌词翻译 $i',
      words: [
        LyricWord(
          text: 'Hello music $i',
          start: Duration(seconds: i * 4),
          end: Duration(seconds: i * 4 + 3),
        ),
      ],
    ),
  ),
);

Future<void> pumpMotion(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(seconds: 2));
  await tester.pump();
}

void main() {
  test(
    'LRC preview preserves source, offsets and playback through replacement',
    () {
      final source = document().copyWith(
        vocalStart: const Duration(seconds: 4),
      );
      final parent = LyricController(
        document: source,
        initialPosition: const Duration(seconds: 8),
        timeOffset: const Duration(milliseconds: 100),
      );
      final preview = StudioPreview(parent);
      expect(parent.document, same(source));
      expect(preview.controller.document!.lines.first.words, isNull);
      expect(preview.controller.document!.lines.last.end, isNull);
      expect(preview.controller.document!.lines.first.translation, '歌词翻译 0');
      expect(preview.controller.document!.tags, source.tags);
      expect(preview.controller.document!.vocalStart, source.vocalStart);
      expect(
        preview.controller.effectivePosition,
        const Duration(milliseconds: 8300),
      );
      parent.setPosition(const Duration(seconds: 12));
      parent.timeOffset = const Duration(milliseconds: 400);
      expect(preview.controller.activeLineIndex, 3);
      expect(
        preview.controller.effectivePosition,
        const Duration(milliseconds: 12600),
      );
      final copy = preview.controller.document;
      parent.setPosition(const Duration(seconds: 16));
      expect(preview.controller.document, same(copy));
      parent.clear();
      expect(preview.controller.document, isNull);
      parent.load('[00:00.00]Replacement');
      expect(preview.controller.document!.lines.single.text, 'Replacement');
      expect(preview.controller.document!.vocalStart, isNull);
      preview.dispose();
      parent.setPosition(Duration.zero);
      expect(parent.position, Duration.zero);
      parent.dispose();
    },
  );

  for (final size in [
    const Size(320, 568),
    const Size(390, 844),
    const Size(1600, 1000),
  ]) {
    testWidgets('one gallery shares timing and effect tuning at $size', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final source = document();
      final parent = LyricController(document: source);
      final state = StudioState();
      addTearDown(parent.dispose);
      addTearDown(state.dispose);
      await tester.pumpWidget(
        MaterialApp(
          theme: studioTheme(),
          home: LyricStudio(
            controller: parent,
            state: state,
            playback: const SizedBox(height: 80),
            onLineTap: (line) => parent.setPosition(line.seekPosition),
          ),
        ),
      );
      await pumpMotion(tester);
      final gallery = find
          .descendant(
            of: find.byType(PresetGallery),
            matching: find.byType(Scrollable),
          )
          .first;
      for (final id in ['apple-music', 'cascade', 'pulse']) {
        final card = find.byKey(ValueKey('preset-$id'));
        await tester.scrollUntilVisible(card, 140, scrollable: gallery);
        await pumpMotion(tester);
        await tester.ensureVisible(card);
        await pumpMotion(tester);
        await tester.tap(card);
        await pumpMotion(tester);
        expect(state.selected.id, id);
        expect(
          tester.widget<LyricView>(find.byType(LyricView)).preset!.wordEffects,
          state.preset.wordEffects,
        );
        expect(find.byType(LyricStudio), findsOneWidget);
        expect(tester.takeException(), isNull);
      }
      state.select(demoPresets.singleWhere((item) => item.id == 'apple-music'));
      await pumpMotion(tester);
      await tester.tap(find.byKey(const ValueKey('timing-mode')));
      await pumpMotion(tester);
      await tester.tap(find.text('普通 LRC').last);
      await pumpMotion(tester);
      final preview = tester
          .widget<LyricView>(find.byType(LyricView))
          .controller;
      expect(preview.document!.lines.first.words, isNull);
      expect(parent.document, same(source));
      parent.setPosition(const Duration(seconds: 12));
      await pumpMotion(tester);
      expect(preview.activeLineIndex, 3);
      await tester.tap(find.byTooltip('原版对照'));
      await pumpMotion(tester);
      expect(
        tester
            .widgetList<LyricView>(find.byType(LyricView))
            .every((view) => identical(view.controller, preview)),
        isTrue,
      );
      await tester.tap(find.byTooltip('原版对照'));
      await pumpMotion(tester);

      if (find.byType(EditPreset).evaluate().isEmpty) {
        await tester.tap(find.text('调节'));
        await pumpMotion(tester);
      }
      await tester.tap(find.byKey(const ValueKey('inspector-tab-2')));
      await tester.pump();
      final inspector = find
          .descendant(
            of: find.byType(EditPreset),
            matching: find.byType(Scrollable),
          )
          .first;
      final clear = find.byKey(const ValueKey('toggle-滑动选择时保持清晰'));
      await tester.scrollUntilVisible(
        clear,
        200,
        scrollable: inspector,
        maxScrolls: 60,
      );
      await pumpMotion(tester);
      await Scrollable.ensureVisible(tester.element(clear), alignment: .5);
      await pumpMotion(tester);
      expect(state.preset.distanceBlur.whenBrowsing, false);
      expect(tester.widget<Switch>(clear).value, true);
      await tester.tap(clear);
      await tester.pump();
      expect(state.preset.distanceBlur.whenBrowsing, true);
      await tester.tap(clear);
      await tester.pump();
      expect(state.preset.distanceBlur.whenBrowsing, false);
      final float = find.byKey(const ValueKey('slider-悬浮周期'));
      await tester.scrollUntilVisible(
        float,
        160,
        scrollable: inspector,
        maxScrolls: 60,
      );
      await pumpMotion(tester);
      await Scrollable.ensureVisible(tester.element(float), alignment: .5);
      await pumpMotion(tester);
      await tester.drag(float, const Offset(25, 0));
      await tester.pump();
      expect(
        state.preset.wordEffects.floatPeriod,
        isNot(LyricPresets.appleMusic.wordEffects.floatPeriod),
      );
      expect(
        state.preset.wordEffects.lift,
        LyricPresets.appleMusic.wordEffects.lift,
      );
      state.undo();
      await tester.pump();
      expect(
        state.preset.wordEffects.floatPeriod,
        LyricPresets.appleMusic.wordEffects.floatPeriod,
      );
      expect(state.preset.distanceBlur.whenBrowsing, false);
      if (size.width < 1180) {
        await tester.tap(find.byTooltip('关闭调节面板'));
        await pumpMotion(tester);
      }
      await tester.tap(find.byKey(const ValueKey('timing-mode')));
      await pumpMotion(tester);
      await tester.tap(find.text('原始逐字时间'));
      await pumpMotion(tester);
      expect(
        tester.widget<LyricView>(find.byType(LyricView)).controller,
        same(parent),
      );
      expect(parent.document, same(source));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
}
