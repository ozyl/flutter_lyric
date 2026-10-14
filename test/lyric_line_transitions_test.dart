import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_lyric/flutter_lyric.dart';
import 'test_support.dart';

const _transitions = {
  'rise': LyricLineTransitions.rise,
  'paper': LyricLineTransitions.paper,
  'spring': LyricLineTransitions.spring,
  'orbit': LyricLineTransitions.orbit,
  'pendulum': LyricLineTransitions.pendulum,
  'zoom': LyricLineTransitions.zoom,
  'step': LyricLineTransitions.step,
  'drift': LyricLineTransitions.drift,
  'focus': LyricLineTransitions.focus,
  'cinematic': LyricLineTransitions.cinematic,
};

LyricLineVisualState _sample(LyricLineTransition transition, double t,
    {bool entering = true, LyricLineVisualState? from, int index = 2}) {
  final start = from ?? transition.state(!entering);
  final end = transition.state(entering);
  final curve = entering ? transition.enterCurve : transition.exitCurve;
  final progress = curve.transform(t);
  return transition.resolver?.call(LyricLineTransitionContext(
        progress: progress,
        from: start,
        to: end,
        index: index,
        activeIndex: entering ? index : index + 1,
        previousActiveIndex: entering ? index - 1 : index,
        entering: entering,
        lineRect: const Rect.fromLTWH(0, 100, 320, 50),
        viewportSize: const Size(320, 400),
      )) ??
      LyricLineVisualState.lerp(start, end, progress);
}

void main() {
  test('motions have distinct trajectories, timing and readable list exits',
      () {
    expect([
      for (var i = 1; i < 20; i++)
        _sample(LyricLineTransitions.spring, i / 20).scale
    ], contains(greaterThan(1)));
    expect(_sample(LyricLineTransitions.orbit, .5).offset.dx, greaterThan(20));
    expect(_sample(LyricLineTransitions.orbit, .5, entering: false).offset.dx,
        lessThan(-20));
    expect(
        _sample(LyricLineTransitions.pendulum, .15).offset.dx, greaterThan(0));
    expect(_sample(LyricLineTransitions.pendulum, .5).offset.dx, lessThan(0));
    expect(_sample(LyricLineTransitions.pendulum, .15, index: 3).offset.dx,
        lessThan(0));
    expect(_sample(LyricLineTransitions.step, .25),
        _sample(LyricLineTransitions.step, .30));
    expect(_sample(LyricLineTransitions.step, .38).offset.dx,
        lessThan(_sample(LyricLineTransitions.step, .30).offset.dx));
    expect(_sample(LyricLineTransitions.cinematic, .5).opacity, lessThan(.6));
    expect(_sample(LyricLineTransitions.cinematic, .5).blurSigma, lessThan(1));
    for (final entry in _transitions.entries) {
      if (entry.key != 'cinematic') {
        expect(entry.value.state(false).opacity, greaterThanOrEqualTo(.45));
      }
    }
  });

  for (final entry in _transitions.entries) {
    final transition = entry.value;
    test(
        '${entry.key} keeps endpoints, finite bounds and captured interruptions',
        () {
      for (final entering in [true, false]) {
        expect(_sample(transition, 0, entering: entering),
            transition.state(!entering));
        expect(_sample(transition, 1, entering: entering),
            transition.state(entering));
        for (var i = 1; i < 100; i++) {
          final value = _sample(transition, i / 100, entering: entering);
          expect(value.offset.distance.isFinite, isTrue);
          expect(value.offset.distance,
              lessThanOrEqualTo(transition.displacementBound + .00001));
          expect(value.scale, inInclusiveRange(.01, transition.scaleBound));
          expect(value.opacity, inInclusiveRange(0, 1));
          expect(value.blurSigma, inInclusiveRange(0, transition.blurBound));
          expect(value.activity, inInclusiveRange(0, 1));
        }
        final captured = _sample(transition, .37, entering: entering);
        expect(_sample(transition, 0, entering: !entering, from: captured),
            captured);
        expect(_sample(transition, 1, entering: !entering, from: captured),
            transition.state(!entering));
        final retimed =
            transition.copyWith(enterDuration: const Duration(seconds: 2));
        expect(_sample(retimed, .4, entering: entering),
            _sample(transition, .4, entering: entering));
      }
    });

    testWidgets('${entry.key} retargets in place and honors reduced motion',
        (tester) async {
      final controller = LyricController(document: lines());
      addTearDown(controller.dispose);
      final preset = quietPreset.copyWith(
        layoutMode: LyricLayoutMode.fixed,
        displayMode: entry.key == 'cinematic'
            ? LyricDisplayMode.activeLine
            : LyricDisplayMode.scrollable,
        lineTransition: transition,
      );
      Widget view(bool reduced) => MediaQuery(
            data: MediaQueryData(disableAnimations: reduced),
            child: host(controller, preset: preset),
          );
      await tester.pumpWidget(view(false));
      controller.setPosition(const Duration(seconds: 1));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 120));
      final captured = session(tester).visualState(1);
      controller.setPosition(const Duration(seconds: 2));
      await tester.pump();
      expect(session(tester).visualState(1), captured);
      await tester.pumpAndSettle();
      expect(session(tester).visualState(2), transition.state(true));
      await tester.pumpWidget(view(true));
      controller.setPosition(const Duration(seconds: 3));
      await tester.pump();
      expect(session(tester).visualState(3), transition.state(true));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }

  test('cinematic crossfade never leaves a dark gap between entries', () {
    const transition = LyricLineTransitions.cinematic;
    for (var elapsed = 0; elapsed <= 800; elapsed += 10) {
      final incoming = _sample(transition,
          (elapsed / transition.enterDuration.inMilliseconds).clamp(0.0, 1.0));
      final outgoing = _sample(transition,
          (elapsed / transition.exitDuration.inMilliseconds).clamp(0.0, 1.0),
          entering: false);
      expect(incoming.opacity + outgoing.opacity, greaterThan(.7));
    }
  });

  for (final mode in LyricLayoutMode.values) {
    testWidgets('step preserves vertical row gaps in $mode', (tester) async {
      final controller = LyricController(document: lines());
      addTearDown(controller.dispose);
      final preset = quietPreset.copyWith(
          layoutMode: mode,
          lineSpacing: 24,
          lineTransition: LyricLineTransitions.step);
      await tester.pumpWidget(host(controller, preset: preset));

      void expectGaps(int active, {required bool settled}) {
        final s = session(tester);
        for (final index in [active - 1, active]) {
          final gap = s.lineRect(index + 1).top - s.lineRect(index).bottom;
          expect(gap, greaterThan(0));
          // Dual-style rows also interpolate their layout offsets while the
          // active font size changes. Fixed rows must keep both gaps throughout.
          if (settled || mode == LyricLayoutMode.fixed) {
            expect(gap, closeTo(preset.lineSpacing, .00001));
          }
        }
      }

      controller.setPosition(const Duration(seconds: 2));
      await tester.pumpAndSettle();
      expectGaps(2, settled: true);
      controller.setPosition(const Duration(seconds: 3));
      await tester.pump();
      for (var frame = 0; frame < 10; frame++) {
        expectGaps(3, settled: false);
        await tester.pump(const Duration(milliseconds: 50));
      }
      expectGaps(3, settled: true);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }

  test('stepped movement remains continuous at hold and segment boundaries',
      () {
    for (final t in [.2, 1 / 3, (1 + .6) / 3, 2 / 3, (2 + .6) / 3]) {
      final before = _sample(LyricLineTransitions.step, t - .000001);
      final after = _sample(LyricLineTransitions.step, t + .000001);
      expect((before.offset - after.offset).distance, lessThan(.001));
      expect((before.opacity - after.opacity).abs(), lessThan(.001));
    }
  });
}
