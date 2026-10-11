// @dart=3.8

import 'package:flutter/material.dart';
import 'package:flutter_lyric/flutter_lyric.dart';
import 'package:flutter_lyric_example/demo_presets.dart';
import 'package:flutter_lyric_example/edit_preset.dart';
import 'package:flutter_lyric_example/issue41_demo_preset.dart';
import 'package:flutter_lyric_example/playback_controls.dart';
import 'package:flutter_lyric_example/studio.dart';
import 'package:flutter_lyric_example/scroll_tuning.dart';
import 'package:flutter_lyric_example/studio_state.dart';
import 'package:flutter_lyric_example/studio_theme.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('gallery reuses the three promoted plugin presets', () {
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

  test('Issue #41 keeps its original geometry when built-in styles evolve', () {
    expect(issue41HighlightOpacityDemo.textStyle.fontSize, 14);
    expect(
      issue41HighlightOpacityDemo.activeAnchor,
      const LyricAnchor.fraction(.3, target: LyricAnchorTarget.mainText),
    );
    expect(issue41HighlightOpacityDemo.lineSpacing, 20);
    expect(
      issue41HighlightOpacityDemo.scrollAnimation.resolve(100).duration,
      const Duration(milliseconds: 240),
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
    'all issue presets retain exact library configuration and custom curves',
    () {
      final experiments = demoPresets.where((e) => e.lab).toList();
      expect(experiments.length, issue41DemoPresets.length);
      for (final entry in issue41DemoPresets.entries) {
        expect(
          experiments.singleWhere((e) => e.id == entry.key).preset,
          same(entry.value),
        );
      }
      final source = issue41DemoPresets['Scroll · Elastic']!.scrollAnimation;
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
    await tester.pumpAndSettle();
    return (state, controller);
  }

  testWidgets('desktop edits live, preserves drafts and compares original', (
    tester,
  ) async {
    final (state, controller) = await mount(tester, const Size(1600, 1000));
    expect(find.byType(EditPreset), findsOneWidget);
    final slider = find.byKey(const ValueKey('slider-当前句大小'));
    await tester.drag(slider, const Offset(35, 0));
    await tester.pumpAndSettle();
    final modified = state.preset;
    expect(modified, isNot(state.selected.preset));
    await tester.tap(find.byKey(const ValueKey('preset-aurora')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('preset-moss')));
    await tester.pumpAndSettle();
    expect(state.preset, modified);
    await tester.tap(find.byTooltip('原版对照'));
    await tester.pumpAndSettle();
    expect(find.byType(LyricView), findsNWidgets(2));
    final views = tester.widgetList<LyricView>(find.byType(LyricView)).toList();
    expect(views[0].preset!.activeTextStyle, modified.activeTextStyle);
    expect(
      views[1].preset!.activeTextStyle,
      state.selected.preset.activeTextStyle,
    );
    expect(views.every((v) => identical(v.controller, controller)), true);
    await tester.tap(find.byTooltip('撤销修改'));
    await tester.pumpAndSettle();
    expect(state.preset, state.selected.preset);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    'phone can adjust every category, close sheet and switch issue preset',
    (tester) async {
      final (state, _) = await mount(tester, const Size(390, 844));
      await tester.tap(find.text('调节'));
      await tester.pumpAndSettle();
      expect(find.byType(EditPreset), findsOneWidget);
      expect(
        tester.getRect(find.byType(LyricView)).bottom,
        lessThan(tester.getTopLeft(find.byType(EditPreset)).dy),
        reason: 'Keep the live lyrics visible above the mobile inspector.',
      );
      await tester.drag(
        find.byKey(const ValueKey('slider-正文大小')),
        const Offset(24, 0),
      );
      await tester.pumpAndSettle();
      expect(state.isModified(state.selected), true);
      for (var i = 1; i < 4; i++) {
        await tester.tap(find.byKey(ValueKey('inspector-tab-$i')));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      }
      await tester.tap(find.byTooltip('关闭调节面板'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('实验室 · 7'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('preset-Issue #41 Gradient')));
      await tester.pumpAndSettle();
      expect(state.selected.name, 'Issue #41');
      await tester.tap(find.byTooltip('原版对照'));
      await tester.pumpAndSettle();
      expect(find.text('ORIGINAL / 原始配置'), findsOneWidget);
      await tester.tap(find.text('返回我的版本'));
      await tester.pumpAndSettle();
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
    await tester.pumpAndSettle();
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
