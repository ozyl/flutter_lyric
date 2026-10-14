// @dart=3.8

import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_lyric/flutter_lyric.dart';
import 'package:flutter_lyric/src/rendering/lyric_viewport.dart';
import 'package:flutter_lyric_example/demo_presets.dart';
import 'package:flutter_lyric_example/edit_preset.dart';
import 'package:flutter_lyric_example/playback_controls.dart';
import 'package:flutter_lyric_example/studio.dart';
import 'package:flutter_lyric_example/scroll_tuning.dart';
import 'package:flutter_lyric_example/studio_state.dart';
import 'package:flutter_lyric_example/studio_theme.dart';
import 'package:flutter_test/flutter_test.dart';

// Character Float intentionally keeps repainting, even with paused playback.
Future<void> pumpStudio(WidgetTester tester) async {
  await tester.pump();
  for (var frame = 0; frame < 75; frame++) {
    await tester.pump(const Duration(milliseconds: 16));
  }
}

void main() {
  test('gallery reuses the promoted plugin presets', () {
    final state = StudioState();
    addTearDown(state.dispose);
    expect(state.selected.id, 'apple-music');
    expect(state.preset, same(LyricPresets.appleMusic));
    expect(
      demoPresets.singleWhere((e) => e.id == 'moss').preset,
      same(LyricPresets.moss),
    );
    expect(
      demoPresets.singleWhere((e) => e.id == 'aurora').preset,
      same(LyricPresets.aurora),
    );
    expect(
      demoPresets.singleWhere((e) => e.id == 'cinema').preset,
      same(LyricPresets.cinema),
    );
  });

  test(
    'drafts, grouped slider undo, redo and reset stay local to each preset',
    () {
      final state = StudioState();
      addTearDown(state.dispose);
      final first = state.selected;
      final original = state.preset;
      state.beginGesture();
      state.update(state.preset.copyWith(lineSpacing: 40));
      state.update(state.preset.copyWith(lineSpacing: 50));
      state.endGesture();
      state.select(demoPresets[1]);
      expect(state.preset, demoPresets[1].preset);
      expect(state.canUndo, false);
      state.update(state.preset.copyWith(lineSpacing: 60));
      state.select(first);
      expect(state.preset.lineSpacing, 50);
      state.undo();
      expect(state.preset, original);
      expect(state.canUndo, false);
      state.redo();
      expect(state.preset.lineSpacing, 50);
      state.reset();
      expect(state.preset, original);
      state.undo();
      expect(state.preset.lineSpacing, 50);
      state.select(demoPresets[1]);
      expect(state.preset.lineSpacing, 60);
    },
  );

  test(
    'scroll tuning preserves distance-based durations and custom curves',
    () {
      final source = LyricScrollAnimation.custom(
        (distance) => LyricAnimation(
          duration: Duration(milliseconds: 1200 + distance.round()),
          curve: Curves.elasticOut,
        ),
      );
      final tuned = tuneScroll(source, milliseconds: 900);
      expect(tuned.resolver, isNotNull);
      expect(tuned.resolve(100).duration.inMilliseconds, 900);
      expect(
        tuned.resolve(500).duration,
        greaterThan(tuned.resolve(100).duration),
      );
      expect(tuned.resolve(100).curve, Curves.elasticOut);
      final curve = tuneScroll(source, curve: Curves.linear);
      expect(curve.resolve(500).duration, source.resolve(500).duration);
      expect(curve.resolve(500).curve, Curves.linear);
      final disabled = tuneScroll(curve, milliseconds: 0);
      final restored = tuneScroll(disabled, milliseconds: 900);
      expect(
        restored.resolve(500).duration,
        greaterThan(restored.resolve(100).duration),
      );
      expect(restored.resolve(500).curve, Curves.linear);
    },
  );

  Future<(StudioState, LyricController)> mount(
    WidgetTester tester,
    Size size, {
    double textScale = 1,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final controller = LyricController()
      ..load(
        '[00:00.00]Be what you wanna be\n[00:03.00]Doctor actor lawyer or a singer\n[00:06.00]You can be just the one you wanna be',
        translation: '[00:00.00]成为你想成为的人\n[00:03.00]医生演员律师或歌手',
      );
    final state = StudioState();
    addTearDown(controller.dispose);
    addTearDown(state.dispose);
    await tester.pumpWidget(
      MaterialApp(
        theme: studioTheme(),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: LyricStudio(
          controller: controller,
          state: state,
          onLineTap: (details) => controller.setPosition(details.seekPosition),
          playback: PlaybackControls(
            position: Duration.zero,
            duration: const Duration(minutes: 3),
            playing: false,
            onPlay: () {},
            onSeek: controller.setPosition,
          ),
        ),
      ),
    );
    await pumpStudio(tester);
    return (state, controller);
  }

  for (final name in ['淡入淡出', '滑入＋淡出', '弹簧回落', '弧光掠入', '分段跃迁', '雾化交叠']) {
    testWidgets('$name keeps neighboring and browsed lyrics visible', (
      tester,
    ) async {
      final (_, controller) = await mount(tester, const Size(1440, 1000));
      controller.loadDocument(
        LyricDocument(
          lines: List.generate(
            20,
            (i) => LyricLine(
              start: Duration(seconds: i),
              text: 'Line $i',
            ),
          ),
        ),
      );
      await pumpStudio(tester);
      await tester.tap(find.byKey(const ValueKey('inspector-tab-2')));
      await pumpStudio(tester);
      final choice = find.byKey(ValueKey('choice-切句动画-$name'));
      await tester.scrollUntilVisible(
        choice,
        120,
        scrollable: find
            .descendant(
              of: find.byType(EditPreset),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await tester.tap(choice);
      await pumpStudio(tester);
      final session = tester
          .renderObject<RenderLyricViewport>(find.byType(LyricViewport))
          .session;
      void expectVisibleRows() {
        final painter = session.painter!;
        final recorder = ui.PictureRecorder();
        painter.paint(Canvas(recorder), session.size);
        recorder.endRecording().dispose();
        expect(painter.debugPaintedLines, greaterThan(1));
      }

      expectVisibleRows();
      controller.setPosition(const Duration(seconds: 1));
      await pumpStudio(tester);
      expectVisibleRows();
      await controller.scrollToLine(12, animate: false);
      await pumpStudio(tester);
      expect(session.selectedIndex, 12);
      expect(session.visibleIndices, isNot(contains(session.activeIndex)));
      expectVisibleRows();
      await tester.tapAt(
        tester.getTopLeft(find.byType(LyricView)) + session.lineRect(12).center,
      );
      await pumpStudio(tester);
      expect(controller.activeLineIndex, 12);
    });
  }

  for (final size in [
    const Size(320, 568),
    const Size(768, 1024),
    const Size(1440, 1000),
  ]) {
    testWidgets('Studio independently tunes Apple transitions at $size', (
      tester,
    ) async {
      final (state, controller) = await mount(tester, size);
      state.select(demoPresets.singleWhere((item) => item.id == 'apple-music'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      if (find.byType(EditPreset).evaluate().isEmpty) {
        await tester.tap(find.text('调节'));
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));
      }
      await tester.tap(find.byKey(const ValueKey('inspector-tab-2')));
      await tester.pump();
      final combination = find.byKey(const ValueKey('choice-切句动画-滑入＋淡出'));
      final inspectorScroll = find
          .descendant(
            of: find.byType(EditPreset),
            matching: find.byType(Scrollable),
          )
          .first;
      await tester.scrollUntilVisible(
        combination,
        120,
        scrollable: inspectorScroll,
      );
      await tester.pump();
      await tester.tap(combination);
      await tester.pump();
      expect(state.preset.lineTransition.effects, const [
        LyricLineEffect.slide(Offset(24, 8)),
        LyricLineEffect.fade(.5),
      ]);
      expect(state.preset.lineMotion, LyricPresets.appleMusic.lineMotion);
      expect(state.preset.wordEffects, LyricPresets.appleMusic.wordEffects);
      final slider = find.byKey(const ValueKey('slider-进入时长'));
      await tester.scrollUntilVisible(
        slider,
        200,
        scrollable: inspectorScroll,
        maxScrolls: 60,
      );
      await tester.pump();
      await tester.drag(slider, const Offset(25, 0));
      await tester.pump();
      expect(state.preset.lineTransition.effects.length, 2);
      expect(
        state.preset.lineTransition.enterDuration,
        isNot(const Duration(milliseconds: 250)),
      );
      controller.setPosition(const Duration(seconds: 3));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(tester.takeException(), isNull);
      state.undo();
      await tester.pump();
      expect(
        state.preset.lineTransition.enterDuration,
        const Duration(milliseconds: 250),
      );
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }

  testWidgets('desktop edits live, preserves drafts and compares original', (
    tester,
  ) async {
    final (state, controller) = await mount(tester, const Size(1600, 1000));
    expect(find.byType(EditPreset), findsOneWidget);
    final slider = find.byKey(const ValueKey('slider-当前句大小'));
    await tester.drag(slider, const Offset(35, 0));
    await pumpStudio(tester);
    final modified = state.preset;
    expect(modified, isNot(state.selected.preset));
    await tester.tap(find.byKey(const ValueKey('preset-aurora')));
    await pumpStudio(tester);
    await tester.tap(find.byKey(const ValueKey('preset-apple-music')));
    await pumpStudio(tester);
    expect(state.preset, modified);
    await tester.tap(find.byTooltip('原版对照'));
    await pumpStudio(tester);
    expect(find.byType(LyricView), findsNWidgets(2));
    final views = tester.widgetList<LyricView>(find.byType(LyricView)).toList();
    expect(views[0].preset!.activeTextStyle, modified.activeTextStyle);
    expect(
      views[1].preset!.activeTextStyle,
      state.selected.preset.activeTextStyle,
    );
    expect(views.every((v) => identical(v.controller, controller)), true);
    await tester.tap(find.byTooltip('撤销修改'));
    await pumpStudio(tester);
    expect(state.preset, state.selected.preset);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    'phone can adjust every category, close sheet and switch presets',
    (tester) async {
      final (state, _) = await mount(tester, const Size(390, 844));
      await tester.tap(find.text('调节'));
      await pumpStudio(tester);
      expect(find.byType(EditPreset), findsOneWidget);
      expect(
        tester.getRect(find.byType(LyricView)).bottom,
        lessThan(tester.getTopLeft(find.byType(EditPreset)).dy),
        reason: 'Keep the live lyrics visible above the mobile inspector.',
      );
      await Scrollable.ensureVisible(
        tester.element(find.byKey(const ValueKey('slider-正文大小'))),
        alignment: .3,
      );
      await tester.pump();
      await tester.drag(
        find.byKey(const ValueKey('slider-正文大小')),
        const Offset(24, 0),
      );
      await pumpStudio(tester);
      expect(state.isModified(state.selected), true);
      for (var i = 1; i < 4; i++) {
        await tester.tap(find.byKey(ValueKey('inspector-tab-$i')));
        await pumpStudio(tester);
        expect(tester.takeException(), isNull);
      }
      await tester.tap(find.byTooltip('关闭调节面板'));
      await pumpStudio(tester);
      await tester.ensureVisible(find.byKey(const ValueKey('preset-aurora')));
      await pumpStudio(tester);
      await tester.tap(find.byKey(const ValueKey('preset-aurora')));
      await pumpStudio(tester);
      expect(state.selected.name, '极光');
      await tester.tap(find.byTooltip('原版对照'));
      await pumpStudio(tester);
      expect(find.text('ORIGINAL / 原始配置'), findsOneWidget);
      await tester.tap(find.text('返回我的版本'));
      await pumpStudio(tester);
      expect(find.text('LIVE STAGE / 实时舞台'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  for (final size in [
    const Size(320, 568),
    const Size(768, 1024),
    const Size(1024, 768),
    const Size(844, 390),
  ]) {
    testWidgets('responsive layout has no overflow at $size', (tester) async {
      await mount(tester, size);
      expect(tester.takeException(), isNull);
      expect(find.byType(LyricView), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }

  testWidgets('phone supports larger system text and audio failure retry', (
    tester,
  ) async {
    await mount(tester, const Size(390, 844), textScale: 1.3);
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('调节'));
    await pumpStudio(tester);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    var retried = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PlaybackControls(
            position: const Duration(seconds: 10),
            duration: Duration.zero,
            playing: false,
            error: '音频加载失败，请重试',
            onPlay: () {},
            onSeek: (_) {},
            onRetry: () => retried = true,
          ),
        ),
      ),
    );
    await tester.tap(find.text('重试'));
    expect(retried, true);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
