import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_lyric/flutter_lyric.dart';
import 'test_support.dart';

const _linear = LyricLineTransition.effects([
  LyricLineEffect.slide(Offset(30, 12)),
  LyricLineEffect.scale(.8),
  LyricLineEffect.fade(.2),
  LyricLineEffect.blur(2),
],
    enterDuration: Duration(seconds: 1),
    exitDuration: Duration(seconds: 2),
    enterCurve: Curves.linear,
    exitCurve: Curves.linear);

void main() {
  test('composition and timing preserve value semantics and explicit bounds',
      () {
    const value = LyricLineTransition.effects([
      LyricLineEffect.slide(Offset(3, 4)),
      LyricLineEffect.slide(Offset(-1, 2)),
      LyricLineEffect.scale(.8),
      LyricLineEffect.scale(.5),
      LyricLineEffect.fade(.4),
      LyricLineEffect.fade(.5),
      LyricLineEffect.blur(3),
      LyricLineEffect.blur(4),
    ]);
    final inactive = value.state(false);
    expect(inactive.offset, const Offset(2, 6));
    expect(inactive.scale, .4);
    expect(inactive.opacity, .2);
    expect(inactive.blurSigma, 5);
    expect(value.blurBound, 5);
    expect(value.displacementBound, greaterThan(inactive.offset.distance));
    expect(value.state(true), const LyricLineVisualState(activity: 1));
    expect(value.copyWith().effects, value.effects);
    expect(const AppleMusicLyricStyle().toPreset(), LyricPresets.appleMusic);
    final original = quietPreset.copyWith(
        lineTransition: value,
        layoutMode: LyricLayoutMode.fixed,
        lineMotion: const LyricLineMotion(maxLag: 12),
        wordEffects: const LyricWordEffects(lift: 2),
        jumpScrollThreshold: 1);
    expect(original.copyWith(), original);
    expect(
        original.copyWith(clearJumpScrollThreshold: true).jumpScrollThreshold,
        isNull);
  });

  for (final mode in LyricLayoutMode.values) {
    testWidgets('browsing does not replay custom line transitions in $mode',
        (tester) async {
      final resolved = <int>{};
      final transition = LyricLineTransition.custom((context) {
        resolved.add(context.index);
        final value = LyricLineVisualState.lerp(
            context.from, context.to, context.progress);
        return LyricLineVisualState(
            offset: value.offset +
                Offset(20 * math.sin(math.pi * context.progress), 0),
            scale: value.scale,
            opacity: value.opacity,
            activity: value.activity);
      },
          effects: const [LyricLineEffect.fade(.5)],
          maxDisplacement: 20,
          maxBlurSigma: 0,
          enterDuration: const Duration(seconds: 1),
          exitDuration: const Duration(seconds: 1),
          enterCurve: Curves.linear,
          exitCurve: Curves.linear);
      final controller = LyricController(document: lines());
      addTearDown(controller.dispose);
      await tester.pumpWidget(host(controller,
          preset: quietPreset.copyWith(
              layoutMode: mode, lineTransition: transition)));
      final s = session(tester);
      s.beginBrowsing();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      expect(s.visibleIndices.map((i) => s.visualState(i).offset.dx),
          everyElement(0));
      expect(resolved, isEmpty);

      await controller.scrollToLine(3, animate: false);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      expect(s.visibleIndices.map((i) => s.visualState(i).offset.dx),
          everyElement(0));
      expect(resolved, isEmpty);
      await controller.resumeFollow(animate: false);
      await tester.pumpAndSettle();
      expect(resolved, isEmpty);

      controller.setPosition(const Duration(seconds: 1));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      expect(s.visualState(0).offset.dx, greaterThan(0));
      expect(s.visualState(1).offset.dx, greaterThan(0));
      expect(s.visualState(2).offset.dx, 0);
      expect(resolved, unorderedEquals([0, 1]));

      // Changing selection midway must not restart the playback clock.
      await controller.scrollToLine(3, animate: false);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      expect(s.activity(1), closeTo(.4, .001));
      expect(resolved, unorderedEquals([0, 1]));
      await tester.pumpAndSettle();
    });

    testWidgets('retargets interrupted state and geometry in $mode',
        (tester) async {
      final controller = LyricController(document: lines());
      addTearDown(controller.dispose);
      await tester.pumpWidget(host(controller,
          preset:
              quietPreset.copyWith(layoutMode: mode, lineTransition: _linear)));
      final s = session(tester);
      // Browsing deliberately holds the list offset; only line transforms move.
      s.beginBrowsing();
      controller.setPosition(const Duration(seconds: 1));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      final before = s.visualState(1);
      final rect = s.lineRect(1);
      expect(before.opacity, closeTo(.52, .001));
      expect(s.activity(0), closeTo(.8, .001));
      controller.setPosition(const Duration(seconds: 2));
      expect(s.visualState(1), before);
      // Dual-style mode deliberately changes paragraph wrapping/height.
      // Its visual transform and row origin continue; fixed mode also keeps
      // the entire paragraph geometry identical.
      expect(s.lineRect(1).topLeft, rect.topLeft);
      if (mode == LyricLayoutMode.fixed) expect(s.lineRect(1), rect);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      final exit = s.visualState(1);
      expect(exit.opacity, lessThan(before.opacity));
      controller.setPosition(const Duration(seconds: 1));
      expect(s.visualState(1), exit);
      await tester.pumpAndSettle();
      expect(s.visualState(1), const LyricLineVisualState(activity: 1));
      expect(s.visualState(0), _linear.state(false));
      expect(tester.takeException(), isNull);
    });
  }

  for (final distanceSigma in [0.0, 4.0]) {
    testWidgets(
        'browsing clears selected row with distance blur $distanceSigma',
        (tester) async {
      final controller = LyricController(document: lines());
      addTearDown(controller.dispose);
      await tester.pumpWidget(host(controller,
          preset: quietPreset.copyWith(
              lineTransition:
                  const LyricLineTransition.effects([LyricLineEffect.blur(3)]),
              distanceBlur: LyricDistanceBlur(maxSigma: distanceSigma))));
      final s = session(tester);
      expect(s.blurFor(0), 0);
      expect(s.blurFor(3), greaterThanOrEqualTo(3));
      await controller.scrollToLine(8, animate: false);
      await tester.pumpAndSettle();
      expect(s.selectedIndex, 8);
      expect(s.blurFor(8), 0);
      expect(s.blurFor(9), greaterThan(0));
      expect(s.activity(8), 0);
      expect(controller.position, Duration.zero);

      await controller.scrollToLine(12, animate: false);
      await tester.pumpAndSettle();
      expect(s.blurFor(12), 0);
      expect(s.blurFor(8), greaterThan(0));
      await controller.resumeFollow(animate: false);
      await tester.pumpAndSettle();
      expect(s.blurFor(0), 0);
      expect(s.blurFor(12), greaterThanOrEqualTo(3));
    });
  }

  testWidgets(
      'custom transition shares one frame with paint, taps and selection',
      (tester) async {
    var resolutions = 0;
    final controller = LyricController(document: lines());
    addTearDown(controller.dispose);
    final taps = <int>[];
    final custom = LyricLineTransition.custom((context) {
      resolutions++;
      expect(context.viewportSize, const Size(400, 240));
      expect(context.lineRect.width, 360);
      final value =
          LyricLineVisualState.lerp(context.from, context.to, context.progress);
      return LyricLineVisualState(
          offset: value.offset +
              Offset(0, 50 * math.sin(math.pi * context.progress)),
          scale: value.scale,
          opacity: value.opacity,
          activity: value.activity);
    },
        effects: const [LyricLineEffect.fade(.5)],
        maxDisplacement: 50,
        maxBlurSigma: 0,
        enterDuration: const Duration(seconds: 1),
        exitDuration: const Duration(seconds: 1),
        enterCurve: Curves.linear,
        exitCurve: Curves.linear);
    await tester.pumpWidget(host(controller,
        preset: quietPreset.copyWith(
            layoutMode: LyricLayoutMode.fixed,
            // The translated row must not overlap the stationary next row.
            lineSpacing: 80,
            lineTransition: custom,
            resumeOnTap: false),
        onLineTap: (line) => taps.add(line.index)));
    final s = session(tester);
    await controller.scrollToLine(1, animate: false);
    controller.setPosition(const Duration(seconds: 1));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    final rect = s.lineRect(1);
    expect(rect.top - s.baseRect(1).top, closeTo(50, .001));
    expect(s.selectionDetails!.lineRect, rect);
    final calls = resolutions;
    final recorder = ui.PictureRecorder();
    s.painter!.paint(Canvas(recorder), s.size);
    disposeNative(recorder.endRecording());
    s.tapAt(rect.center);
    expect(taps, [1]);
    // A tap can start a wave, but plain paint and geometry do not re-resolve.
    expect(resolutions, calls);
    await tester.pumpAndSettle();
    expect(s.visualState(1).offset, Offset.zero);
  });

  testWidgets(
      'activeLine crossfade retains, reuses and releases outgoing paragraphs',
      (tester) async {
    final controller = LyricController(document: lines());
    addTearDown(controller.dispose);
    final preset = quietPreset.copyWith(
        displayMode: LyricDisplayMode.activeLine,
        layoutMode: LyricLayoutMode.fixed,
        lineTransition: const LyricLineTransition.effects(
            [LyricLineEffect.fade(0)],
            enterDuration: Duration(seconds: 1),
            exitDuration: Duration(seconds: 1),
            enterCurve: Curves.linear,
            exitCurve: Curves.linear));
    await tester.pumpWidget(host(controller, preset: preset));
    final s = session(tester);
    final first = s.layout;
    controller.setPosition(const Duration(seconds: 1));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(s.visibleIndices.toList(), [0, 1]);
    expect(s.layoutFor(0), same(first));
    expect(s.visualState(0).opacity, closeTo(.6, .001));
    expect(s.visualState(1).opacity, closeTo(.4, .001));
    final current = s.visualState(0);
    controller.setPosition(Duration.zero);
    expect(s.visualState(0), current);
    await tester.pump();
    expect(s.layout, same(first));
    expect(s.visibleIndices.toList(), [1, 0]);
    await tester.pumpAndSettle();
    expect(s.visibleIndices.toList(), [0]);
    expect(s.layoutFor(1), isNull);
    controller.clear();
    await tester.pumpAndSettle();
    expect(s.layout, isNull);
    expect(s.visibleIndices, isEmpty);
  });

  testWidgets(
      'activeLine releases exits while a longer entrance is still running',
      (tester) async {
    final controller = LyricController(document: lines());
    addTearDown(controller.dispose);
    await tester.pumpWidget(host(controller,
        preset: quietPreset.copyWith(
            displayMode: LyricDisplayMode.activeLine,
            lineTransition: const LyricLineTransition.effects(
                [LyricLineEffect.fade(0)],
                enterDuration: Duration(seconds: 1),
                exitDuration: Duration(milliseconds: 200),
                enterCurve: Curves.linear,
                exitCurve: Curves.linear))));
    final s = session(tester);
    controller.setPosition(const Duration(seconds: 1));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(s.layoutFor(0), isNull);
    expect(s.visibleIndices.toList(), [1]);
    expect(s.activity(1), closeTo(.3, .001));
    await tester.pumpAndSettle();
  });

  testWidgets('outgoing timed highlight keeps its last sampled position',
      (tester) async {
    final controller = LyricController(
        document: lines(), initialPosition: const Duration(milliseconds: 500));
    addTearDown(controller.dispose);
    await tester.pumpWidget(host(controller,
        preset: quietPreset.copyWith(
            lineTransition: _linear,
            highlight: const LyricHighlight.solid(Color(0xFFFFFFFF)))));
    final s = session(tester);
    final width = s.layout!.metric(0).words!.single.width;
    controller.setPosition(const Duration(seconds: 2));
    await tester.pump();
    expect(s.highlightWidthFor(0, false), closeTo(width * .5, .001));
    await tester.pump(const Duration(milliseconds: 300));
    expect(s.highlightWidthFor(0, false), closeTo(width * .5, .001));
    await tester.pumpAndSettle();
  });

  testWidgets('fixed layout keeps active geometry and distinct inactive color',
      (tester) async {
    final controller = LyricController(document: lines());
    addTearDown(controller.dispose);
    await tester.pumpWidget(host(controller,
        preset: quietPreset.copyWith(
            layoutMode: LyricLayoutMode.fixed, lineTransition: _linear)));
    final s = session(tester);
    expect(s.layout!.style.textStyle.color, quietPreset.textStyle.color);
    expect(s.layout!.style.activeTextStyle.color,
        quietPreset.activeTextStyle.color);
    expect(s.layout!.metric(1).height, s.layout!.metric(1).activeHeight);
    expect(s.layout!.metric(1).textPainter.text!.style!.fontSize, 18);
    final metrics = s.layout!.metrics;
    controller.setPosition(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(s.layout!.metrics, same(metrics));
  });

  testWidgets('activeLine handles multiple seeks before the next frame',
      (tester) async {
    final controller = LyricController(document: lines());
    addTearDown(controller.dispose);
    await tester.pumpWidget(host(controller,
        preset: quietPreset.copyWith(
            displayMode: LyricDisplayMode.activeLine,
            layoutMode: LyricLayoutMode.fixed,
            lineTransition:
                const LyricLineTransition.effects([LyricLineEffect.fade(0)]))));
    final s = session(tester);
    controller.setPosition(const Duration(seconds: 1));
    controller.setPosition(const Duration(seconds: 2));
    controller.setPosition(const Duration(seconds: 3));
    await tester.pump();
    expect(s.visibleIndices.toList(), [0, 3]);
    await tester.pumpAndSettle();
    expect(s.visibleIndices.toList(), [3]);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'custom output is bounded and translated offscreen lines stay paintable',
      (tester) async {
    final controller = LyricController(document: lines());
    addTearDown(controller.dispose);
    final transition = LyricLineTransition.custom(
        (context) => const LyricLineVisualState(
            offset: Offset(0, -10000), opacity: -2, blurSigma: 40, scale: 5),
        effects: const [LyricLineEffect.slide(Offset(0, -250))],
        maxDisplacement: 250,
        maxBlurSigma: 3,
        maxScale: 1.2);
    await tester.pumpWidget(host(controller,
        preset: quietPreset.copyWith(
            layoutMode: LyricLayoutMode.fixed, lineTransition: transition)));
    final s = session(tester);
    final shifted = s.visibleIndices
        .where((i) =>
            s.baseRect(i).top > s.size.height &&
            s.lineRect(i).overlaps(Offset.zero & s.size))
        .toList();
    expect(shifted, isNotEmpty);
    controller.setPosition(const Duration(seconds: 1));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    final value = s.visualState(1);
    expect(value.offset.distance, lessThanOrEqualTo(250));
    expect(value.opacity, 0);
    expect(value.blurSigma, 3);
    expect(value.scale, 1.2);
    await tester.pumpAndSettle();
  });

  testWidgets(
      'word effects can be reused on dual-style presets without per-frame layout',
      (tester) async {
    final controller = LyricController(
        document: lines(), initialPosition: const Duration(milliseconds: 500));
    addTearDown(controller.dispose);
    await tester.pumpWidget(host(controller,
        preset: quietPreset.copyWith(
            wordEffects: const LyricWordEffects(lift: 2.5, floatAmplitude: 1.4),
            highlight: const LyricHighlight.solid(Color(0xFFFFFFFF)))));
    final s = session(tester);
    final metrics = s.layout!.metrics;
    expect(metrics.first.debugCharactersComputed, true);
    expect(metrics.last.debugWordLineComputed, false);
    await tester.pump(const Duration(milliseconds: 600));
    expect(s.layout!.metrics, same(metrics));
    expect(s.characterFloatLift(0, 0), isNot(0));
    expect(s.characterFloatLift(0, 5), 0);
    expect(controller.position, const Duration(milliseconds: 500));
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('hidden and reduced motion stop generic custom transitions',
      (tester) async {
    final controller = LyricController(document: lines());
    addTearDown(controller.dispose);
    Widget view({bool enabled = true, bool reduced = false}) => MediaQuery(
        data: MediaQueryData(disableAnimations: reduced),
        child: TickerMode(
            enabled: enabled,
            child: host(controller,
                preset: quietPreset.copyWith(lineTransition: _linear))));
    await tester.pumpWidget(view());
    controller.setPosition(const Duration(seconds: 1));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    expect(session(tester).activity(1), lessThan(1));
    await tester.pumpWidget(view(reduced: true));
    await tester.pumpAndSettle();
    expect(session(tester).activity(1), 1);
    expect(tester.binding.transientCallbackCount, 0);
    await tester.pumpWidget(view(enabled: false));
    controller.setPosition(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    expect(session(tester).activity(2), 1);
    expect(tester.binding.transientCallbackCount, 0);
  });

  testWidgets(
      'disabled effects leave offscreen caches and animation clocks idle',
      (tester) async {
    final controller = LyricController(document: lines(count: 1000));
    addTearDown(controller.dispose);
    await tester.pumpWidget(host(controller, preset: quietPreset));
    await tester.pumpAndSettle();
    expect(
        session(tester).layout!.metrics.every((m) => !m.debugWordLineComputed),
        true);
    expect(tester.binding.transientCallbackCount, 0);
  });
}
