import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_lyric/flutter_lyric.dart';
import 'package:flutter_lyric/src/model/lyric_gap.dart';
import 'package:flutter_lyric/src/rendering/lyric_viewport.dart';
import 'test_support.dart';

Duration seconds(int value) => Duration(seconds: value);
LyricLine line(int start, {int? end, String text = 'Lyric'}) => LyricLine(
    start: seconds(start), end: end == null ? null : seconds(end), text: text);
LyricDocument song() => LyricDocument(lines: [
      line(10, end: 12),
      line(22, end: 25),
      line(27, end: 30),
    ]);

void main() {
  const config = LyricCountdown(breathDuration: Duration(seconds: 7));
  test('only verified silence counts, including blank LRC markers', () {
    final timeline = LyricGapTimeline(song());
    expect(timeline.at(seconds(0), config)!.isIntro, isTrue);
    expect(timeline.at(seconds(10), config), isNull);
    expect(timeline.at(seconds(11), config), isNull);
    final gap = timeline.at(seconds(12), config)!;
    expect(gap.nextIndex, 1);
    expect(gap.isIntro, isFalse);
    expect(gap.end, seconds(22));
    expect(timeline.at(seconds(22), config), isNull);
    expect(timeline.at(seconds(25), config), isNull);
    expect(timeline.at(seconds(60), config), isNull);
    expect(timeline.at(seconds(-1), config), isNull);
    expect(timeline.at(seconds(0), const LyricCountdown.none()), isNull);
    final lrc = LyricGapTimeline(LyricDocument.parse(
        '[00:10]Long lyric\n[00:30]Next\n[00:32]\n[00:40]After silence\n[00:42]'));
    expect(lrc.at(seconds(20), config), isNull);
    expect(lrc.at(seconds(32), config)!.end, seconds(40));
    expect(lrc.at(seconds(45), config), isNull);
  });

  test('word ends, overlapping and simultaneous lines are conservative', () {
    final timeline = LyricGapTimeline(LyricDocument(lines: [
      LyricLine(start: seconds(0), text: 'Timed', words: [
        LyricWord(text: 'Timed', start: seconds(0), end: seconds(2)),
      ]),
      line(10, end: 25),
      line(10, end: 12),
      line(15, text: ''),
      line(20, end: 22),
      line(32, end: 33),
    ]));
    expect(timeline.at(seconds(2), config)!.end, seconds(10));
    expect(timeline.at(seconds(12), config), isNull);
    expect(timeline.at(seconds(23), config), isNull);
    expect(timeline.at(seconds(25), config)!.end, seconds(32));
    final incomplete = LyricGapTimeline(LyricDocument(lines: [
      LyricLine(start: seconds(0), text: 'Missing word end', words: [
        LyricWord(text: 'Missing', start: seconds(0), end: seconds(2)),
        LyricWord(text: 'end', start: seconds(3)),
      ]),
      line(20),
    ]));
    expect(incomplete.at(seconds(10), config), isNull);
    expect(LyricGapTimeline(LyricDocument(lines: [line(0, text: '')])).gaps,
        isEmpty);
  });

  test('duration is the minimum gap and is independent of dot count', () {
    final timeline = LyricGapTimeline(song());
    const countdown =
        LyricCountdown(dotCount: 6, dotDuration: Duration(seconds: 3));
    expect(timeline.at(seconds(6), countdown), isNull);
    final gap = timeline.at(seconds(7), countdown)!;
    expect(gap.displayStart(countdown), seconds(7));
    expect(gap.dotProgress(seconds(8), countdown), closeTo(1 / 3, .00001));
    expect(timeline.at(seconds(26), countdown), isNull);
    final exact = LyricGapTimeline(LyricDocument(lines: [line(3)]));
    expect(
        exact
            .at(Duration.zero, countdown)!
            .dotProgress(Duration.zero, countdown),
        0);
    expect(exact.at(seconds(3), countdown), isNull);
    final short = LyricGapTimeline(LyricDocument(lines: [
      LyricLine(start: const Duration(microseconds: 2999999), text: 'Too soon'),
    ]));
    expect(short.at(Duration.zero, countdown), isNull);
  });

  test('breathing uses only excess gap time without shortening the fade', () {
    final timeline = LyricGapTimeline(song());
    const countdown =
        LyricCountdown(breathDuration: Duration(milliseconds: 1500));
    expect(timeline.at(const Duration(milliseconds: 5499), countdown), isNull);
    final gap = timeline.at(const Duration(milliseconds: 5500), countdown)!;
    expect(gap.displayStart(countdown), const Duration(milliseconds: 5500));
    expect(gap.dotProgress(seconds(6), countdown), 0);
    expect(gap.dotProgress(seconds(7), countdown), 0);
    expect(gap.dotProgress(const Duration(milliseconds: 7500), countdown),
        closeTo(1 / 6, .00001));
    expect(gap.dotProgress(seconds(9), countdown), closeTo(2 / 3, .00001));
    expect(timeline.at(seconds(10), countdown), isNull);
    final full = countdown.copyWith(breathDuration: seconds(30));
    expect(timeline.at(Duration.zero, full)!.displayStart(full), Duration.zero);
    final exact = LyricGapTimeline(LyricDocument(lines: [line(3)]));
    expect(exact.at(Duration.zero, full)!.dotProgress(seconds(1), full),
        closeTo(1 / 3, .00001));
    final short = LyricGapTimeline(LyricDocument(lines: [line(2)]));
    expect(short.at(Duration.zero, full), isNull);
  });

  test('config participates in preset equality and nullable clearing', () {
    final custom = config.copyWith(color: const Color(0xFF123456));
    expect(const LyricPreset().countdown.enabled, isTrue);
    expect(const LyricPreset().copyWith(countdown: custom).countdown, custom);
    expect(custom.copyWith(clearColor: true), config);
    expect(custom.copyWith(), custom);
    expect(custom.copyWith().hashCode, custom.hashCode);
    for (final changed in [
      config.copyWith(dotDuration: seconds(4)),
      config.copyWith(dotCount: 5),
      config.copyWith(direction: LyricCountdownDirection.rightToLeft),
      config.copyWith(breathDuration: seconds(1)),
    ]) {
      expect(changed, isNot(config));
      expect(changed.copyWith(), changed);
    }
    expect(
        () => custom.copyWith(clearColor: true, color: const Color(0xFF000000)),
        throwsArgumentError);
  });

  for (final mode in LyricDisplayMode.values) {
    testWidgets('extra wait breathes with playback and rejoins fading in $mode',
        (tester) async {
      final controller = LyricController(
          document: song(),
          initialPosition: const Duration(milliseconds: 5400));
      addTearDown(controller.dispose);
      const active = Color(0x80FFFFFF);
      const inactive = Color(0x20000000);
      final preset = quietPreset.copyWith(
        displayMode: mode,
        countdown: config.copyWith(
          breathDuration: seconds(2),
          color: active,
          inactiveColor: inactive,
        ),
      );
      List<double> scales() =>
          countdownDots(tester).map((dot) => dot.radius / 4).toList();
      List<Color> colors() =>
          countdownDots(tester).map((dot) => dot.color).toList();

      await tester.pumpWidget(host(controller, preset: preset));
      await tester.pumpAndSettle();
      final bounds = session(tester).countdownFrame!.rect;
      expect(scales(), everyElement(closeTo(1, .00001)));
      expect(colors(), everyElement(colorCloseTo(active)));

      controller.setPosition(const Duration(milliseconds: 6200));
      await tester.pumpAndSettle();
      expect(scales(), everyElement(closeTo(.86, .00001)));
      final dimmed = colors();
      expect(dimmed, everyElement(dimmed.first));
      expect(channel(dimmed.first, 'a'),
          closeTo(channel(active, 'a') * .65, .005));
      expect(session(tester).countdownFrame!.rect, bounds);
      expect(session(tester).countdownFrame!.dotProgress, 0);
      await tester.pump(seconds(2));
      expect(scales(), everyElement(closeTo(.86, .00001)));
      expect(colors(), dimmed);
      expect(controller.position, const Duration(milliseconds: 6200));

      controller.setPosition(const Duration(milliseconds: 5400));
      await tester.pumpAndSettle();
      expect(scales(), everyElement(closeTo(1, .00001)));
      expect(colors(), everyElement(colorCloseTo(active)));
      controller.setPosition(const Duration(milliseconds: 6999));
      await tester.pumpAndSettle();
      expect(scales(), everyElement(closeTo(1, .00001)));
      expect(channel(colors().first, 'a'), closeTo(channel(active, 'a'), .005));
      controller.setPosition(seconds(7));
      await tester.pumpAndSettle();
      expect(scales(), everyElement(1));
      expect(colors(), everyElement(colorCloseTo(active)));
      controller.setPosition(const Duration(milliseconds: 7500));
      await tester.pumpAndSettle();
      expect(scales(), everyElement(1));
      final fading = colors();
      final halfFaded = Color.lerp(active, inactive, .5)!;
      for (final component in ['a', 'r', 'g', 'b']) {
        expect(channel(fading.first, component),
            closeTo(channel(halfFaded, component), .005));
      }
      expect(fading.skip(1), everyElement(colorCloseTo(active)));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('countdown pause, seek, offset and reconfiguration in $mode',
        (tester) async {
      final controller =
          LyricController(document: song(), initialPosition: seconds(5));
      addTearDown(controller.dispose);
      final perSecond = config.copyWith(
        breathDuration: seconds(2),
      );
      final preset =
          quietPreset.copyWith(countdown: perSecond, displayMode: mode);
      await tester.pumpWidget(host(controller, preset: preset));
      await tester.pumpAndSettle();
      final state = session(tester);
      expect(state.countdownFrame!.progress, 0);
      expect(state.countdownFrame!.dotProgress, 0);
      controller.setPosition(seconds(8));
      await tester.pumpAndSettle();
      expect(state.countdownFrame!.progress, .6);
      expect(state.countdownFrame!.dotProgress, closeTo(1 / 3, .00001));
      expect(countdownDots(tester), hasLength(3));
      final scroll = state.scrollY;
      await tester.pump(seconds(4));
      expect(state.countdownFrame!.dotProgress, closeTo(1 / 3, .00001));
      expect(state.scrollY, scroll);
      controller.setPosition(seconds(4));
      await tester.pumpAndSettle();
      expect(state.hasCountdown, isFalse);
      controller.timeOffset = seconds(2);
      await tester.pumpAndSettle();
      expect(state.countdownFrame!.dotProgress, 0);
      controller.setPosition(seconds(6));
      await tester.pumpAndSettle();
      expect(state.countdownFrame!.dotProgress, closeTo(1 / 3, .00001));
      // Edit duration while still in the same gap: anchor and progress update.
      await tester.pumpWidget(host(controller,
          preset: preset.copyWith(
            countdown: perSecond.copyWith(
                dotDuration: seconds(10), breathDuration: Duration.zero),
          )));
      await tester.pumpAndSettle();
      expect(state.countdownFrame!.dotProgress, .8);
      expect(state.countdownFrame!.rect.center.dy, closeTo(120, .01));
      controller.loadDocument(LyricDocument(lines: [line(0)]));
      await tester.pumpAndSettle();
      expect(session(tester).hasCountdown, isFalse);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }

  for (final duration in [Duration.zero, seconds(-1)]) {
    testWidgets('non-positive dot duration $duration is rejected',
        (tester) async {
      final controller = LyricController(document: song());
      addTearDown(controller.dispose);
      await tester.pumpWidget(host(controller,
          preset: quietPreset.copyWith(
            countdown: config.copyWith(dotDuration: duration),
          )));
      expect(tester.takeException(), isArgumentError);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }

  for (final mode in LyricDisplayMode.values) {
    for (final layoutMode in LyricLayoutMode.values) {
      testWidgets(
          'dots exclusively own focus through entry, seek and reconfiguration in $mode/$layoutMode',
          (tester) async {
        final controller =
            LyricController(document: song(), initialPosition: seconds(18));
        addTearDown(controller.dispose);
        final preset = quietPreset.copyWith(
          displayMode: mode,
          layoutMode: layoutMode,
          countdown: const LyricCountdown(),
          lineTransition: LyricLineTransitions.appleMusic,
          distanceBlur: const LyricDistanceBlur(maxSigma: 4),
        );
        await tester.pumpWidget(host(controller, preset: preset));
        await tester.pumpAndSettle();
        final state = session(tester);
        expect(state.activity(0), 1);
        controller.setPosition(seconds(19));
        await tester.pump();
        expect(controller.activeLineIndex, 0);
        expect(state.activeIndex, -1);
        expect(state.hasCountdown, isTrue);
        for (var frame = 0; frame < 30; frame++) {
          expect(state.activity(0), 0);
          expect(state.activity(1), 0);
          expect(state.paintsActive(0), isFalse);
          await tester.pump(const Duration(milliseconds: 16));
        }
        expect(state.focus, .5);
        controller.setPosition(seconds(22));
        await tester.pumpAndSettle();
        expect(state.hasCountdown, isFalse);
        expect(state.activeIndex, 1);
        expect(state.activity(1), 1);
        controller.setPosition(seconds(20));
        await tester.pump();
        expect(state.activity(1), 0);
        expect(state.hasCountdown, isTrue);
        await tester.pumpWidget(host(controller,
            preset: preset.copyWith(countdown: const LyricCountdown.none())));
        await tester.pumpAndSettle();
        expect(state.activeIndex, 0);
        expect(state.activity(0), 1);
        await tester.pumpWidget(host(controller, preset: preset));
        await tester.pump();
        expect(state.hasCountdown, isTrue);
        expect(state.activity(0), 0);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      });
    }
  }

  testWidgets('negative extra wait is rejected', (tester) async {
    final controller = LyricController(document: song());
    addTearDown(controller.dispose);
    await tester.pumpWidget(host(controller,
        preset: quietPreset.copyWith(
          countdown: config.copyWith(breathDuration: seconds(-1)),
        )));
    expect(tester.takeException(), isArgumentError);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
      'breathing respects reduced motion, ticker mode and the fading phase',
      (tester) async {
    final controller = LyricController(document: song());
    addTearDown(controller.dispose);
    final perSecond = config.copyWith(
      breathDuration: seconds(2),
      color: const Color(0xFFFFFFFF),
    );
    Future<void> check(LyricCountdown countdown,
        {Duration remaining = const Duration(milliseconds: 3800),
        bool reduced = false,
        bool enabled = true,
        bool breathes = false}) async {
      controller.setPosition(seconds(10) - remaining);
      await tester.pumpWidget(MediaQuery(
        data: MediaQueryData(disableAnimations: reduced),
        child: TickerMode(
          enabled: enabled,
          child: host(controller,
              preset: quietPreset.copyWith(countdown: countdown)),
        ),
      ));
      await tester.pumpAndSettle();
      final dots = countdownDots(tester);
      expect(dots, hasLength(3));
      for (final dot in dots) {
        expect(dot.radius, breathes ? lessThan(4) : 4);
        if (remaining >= seconds(3)) {
          expect(channel(dot.color, 'a'), breathes ? lessThan(1) : 1);
        }
      }
    }

    await check(perSecond, breathes: true);
    await check(perSecond, reduced: true);
    await check(perSecond, enabled: false);
    await check(perSecond, remaining: seconds(3));
    await check(perSecond, remaining: seconds(2));
    await check(perSecond.copyWith(breathDuration: Duration.zero),
        remaining: seconds(3));
    await check(
        perSecond.copyWith(
            dotDuration: seconds(10), breathDuration: Duration.zero),
        remaining: seconds(10));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  for (final mode in LyricDisplayMode.values) {
    testWidgets('countdown follows playback, seeks and replacement in $mode',
        (tester) async {
      final controller = LyricController(document: song());
      addTearDown(controller.dispose);
      final preset = quietPreset.copyWith(
          countdown: config,
          displayMode: mode,
          emptyBuilder: (_) => const Text('Empty'));
      await tester.pumpWidget(host(controller, preset: preset));
      await tester.pumpAndSettle();
      final state = session(tester);
      expect(session(tester).hasCountdown, isTrue);
      expect(find.text('Empty'), findsNothing);
      expect(state.countdownFrame!.rect.center.dy, closeTo(120, .01));
      if (mode == LyricDisplayMode.scrollable) {
        expect(
            state.countdownFrame!.rect.bottom, lessThan(state.lineRect(0).top));
      }
      final viewport = tester.widget(find.byType(LyricViewport));
      final metrics = state.layout?.metrics;
      controller.setPosition(seconds(5));
      await tester.pumpAndSettle();
      expect(state.countdownFrame!.progress, .5);
      expect(state.countdownFrame!.remaining, seconds(5));
      await tester.pump(seconds(20)); // A paused clock does not advance dots.
      expect(state.countdownFrame!.progress, .5);
      expect(tester.binding.transientCallbackCount, 0);
      expect(tester.widget(find.byType(LyricViewport)), same(viewport));
      expect(state.layout?.metrics, same(metrics));
      for (final position in [10, 12, 18, 22, 26, 50, 5]) {
        controller.setPosition(seconds(position));
        await tester.pumpAndSettle();
        expect(state.hasCountdown, [12, 18, 5].contains(position));
        if (state.hasCountdown) {
          expect(state.countdownFrame!.rect.center.dy, closeTo(120, .01));
          if (mode == LyricDisplayMode.activeLine) {
            expect(state.visibleIndices, isEmpty);
          }
        }
        expect(tester.takeException(), isNull);
      }
      controller.loadDocument(LyricDocument(lines: [line(0), line(2)]));
      await tester.pumpAndSettle();
      expect(session(tester).hasCountdown, isFalse);
      controller.clear();
      await tester.pumpAndSettle();
      expect(find.text('Empty'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }

  testWidgets('canvas countdown uses corrected time and only repaints progress',
      (tester) async {
    final controller =
        LyricController(document: song().copyWith(offset: seconds(2)));
    addTearDown(controller.dispose);
    final preset = quietPreset.copyWith(
        countdown: config.copyWith(breathDuration: Duration.zero));
    await tester.pumpWidget(host(controller, preset: preset, viewId: 'canvas'));
    await tester.pumpAndSettle();
    final state = session(tester);
    expect(state.hasCountdown, isFalse);
    expect(countdownDots(tester), isEmpty);
    controller.setPosition(seconds(5));
    await tester.pumpAndSettle();
    expect(countdownDots(tester), hasLength(3));
    expect(state.countdownFrame!.remaining, seconds(3));
    expect(state.lineDetails(state.countdownFrame!.nextIndex).viewId, 'canvas');
    expect(state.lineDetails(state.countdownFrame!.nextIndex).seekPosition,
        seconds(8));
    final presentation = state.presentation.value;
    final viewport = tester.widget(find.byType(LyricViewport));
    controller.setPosition(seconds(6));
    await tester.pumpAndSettle();
    expect(state.countdownFrame!.remaining, seconds(2));
    expect(state.countdownFrame!.progress, closeTo(1 / 3, .00001));
    expect(state.presentation.value, presentation);
    expect(tester.widget(find.byType(LyricViewport)), same(viewport));
    controller.timeOffset = seconds(1);
    await tester.pumpAndSettle();
    expect(state.countdownFrame!.remaining, seconds(1));
    expect(state.lineDetails(state.countdownFrame!.nextIndex).seekPosition,
        seconds(7));
    await tester.pumpWidget(host(controller, preset: quietPreset));
    await tester.pumpAndSettle();
    expect(countdownDots(tester), isEmpty);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('dragging scrolls dots out and back without hiding the countdown',
      (tester) async {
    final controller = LyricController(
        document: LyricDocument(lines: [
      for (var i = 0; i < 30; i++) line(10 + i * 12, end: 12 + i * 12),
    ]));
    addTearDown(controller.dispose);
    await tester.pumpWidget(
        host(controller, preset: quietPreset.copyWith(countdown: config)));
    await tester.pumpAndSettle();
    final state = session(tester);
    final initial = state.countdownFrame!.rect;
    final initialScroll = state.scrollY;
    final gesture =
        await tester.startGesture(tester.getCenter(find.byType(LyricViewport)));
    await gesture.moveBy(const Offset(0, -24));
    await tester.pump();
    await gesture.moveBy(const Offset(0, -12));
    await tester.pump();
    expect(state.following, isFalse);
    expect(state.hasCountdown, isTrue);
    expect(state.countdownFrame!.rect.top,
        closeTo(initial.top - (state.scrollY - initialScroll), .01));
    expect(countdownDots(tester), hasLength(3));
    await gesture.up();
    await tester.pumpAndSettle();
    controller.setPosition(seconds(5));
    await tester.pumpAndSettle();
    expect(state.countdownFrame!.progress, .5);
    state.scrollController
        .jumpTo(state.scrollController.position.maxScrollExtent);
    await tester.pumpAndSettle();
    expect(state.hasCountdown, isTrue);
    expect(countdownDots(tester), isEmpty);
    state.scrollController.jumpTo(initialScroll);
    await tester.pumpAndSettle();
    expect(state.following, isFalse);
    expect(countdownDots(tester), hasLength(3));
    await controller.resumeFollow(animate: false);
    await tester.pumpAndSettle();
    expect(state.countdownFrame!.rect, initial);
    expect(countdownDots(tester), hasLength(3));
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
      'shared playback keeps countdown configuration local to each view',
      (tester) async {
    final source = _CountdownSource();
    final controller =
        LyricController(document: song(), progressSource: source);
    addTearDown(controller.dispose);
    addTearDown(source.dispose);
    Widget views({bool enabled = true}) => TickerMode(
        enabled: enabled,
        child: Directionality(
            textDirection: TextDirection.ltr,
            child: Row(children: [
              Expanded(
                  child: LyricView(
                      controller: controller,
                      preset: quietPreset.copyWith(countdown: config))),
              Expanded(
                  child: LyricView(
                      controller: controller,
                      preset: quietPreset.copyWith(
                          countdown:
                              config.copyWith(breathDuration: Duration.zero)))),
            ])));
    await tester.pumpWidget(views());
    await tester.pumpAndSettle();
    expect(session(tester).hasCountdown, isTrue);
    source.position = seconds(5);
    source.isAdvancing = true;
    source.events.add(null);
    await tester.pump();
    source.position = seconds(8);
    await tester.pump(const Duration(milliseconds: 16));
    await tester.pump();
    expect(session(tester).hasCountdown, isTrue);
    expect(session(tester, at: 1).hasCountdown, isTrue);
    expect(session(tester).countdownFrame!.progress, .8);
    expect(
        session(tester, at: 1).countdownFrame!.progress, closeTo(1 / 3, .001));
    source.isAdvancing = false;
    source.events.add(null);
    await tester.pumpAndSettle();
    await tester.pump(seconds(5));
    expect(session(tester).countdownFrame!.progress, .8);
    expect(tester.binding.transientCallbackCount, 0);
    await tester.pumpWidget(views(enabled: false));
    source.position = seconds(1);
    source.events.add(null);
    await tester.pumpAndSettle();
    expect(session(tester).hasCountdown, isTrue);
    expect(session(tester).countdownFrame!.progress, .1);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
      'fixed layout reuses paragraphs when toggling countdown and resizing',
      (tester) async {
    final controller = LyricController(document: song())
      ..setPosition(seconds(15));
    addTearDown(controller.dispose);
    final base = quietPreset.copyWith(layoutMode: LyricLayoutMode.fixed);
    await tester.pumpWidget(host(controller, preset: base));
    await tester.pumpAndSettle();
    final metrics = session(tester).layout!.metrics;
    await tester
        .pumpWidget(host(controller, preset: base.copyWith(countdown: config)));
    await tester.pumpAndSettle();
    expect(session(tester).layout!.metrics, same(metrics));
    expect(session(tester).countdownFrame!.rect.center.dy, closeTo(120, .01));
    await tester.pumpWidget(host(controller,
        size: const Size(400, 320),
        preset: base.copyWith(countdown: config.copyWith(height: 40))));
    await tester.pumpAndSettle();
    expect(session(tester).countdownFrame!.rect.center.dy, closeTo(160, .01));
    expect(session(tester).layout!.metrics, same(metrics));
    final current = session(tester).layout!;
    final lyricPositions = [for (var i = 0; i < 3; i++) current.lineTop(i, 0)];
    final contentHeight = current.contentHeight(0);
    final extent = current.countdownExtent;
    expect(current.countdownIndices, [1]);
    controller.setPosition(seconds(22));
    await tester.pumpAndSettle();
    expect(session(tester).hasCountdown, isFalse);
    expect(current.countdownIndices, isEmpty);
    expect(current.countdownExtent, 0);
    expect([
      for (var i = 0; i < 3; i++) current.lineTop(i, 1)
    ], [
      lyricPositions[0],
      lyricPositions[1] - extent,
      lyricPositions[2] - extent,
    ]);
    expect(current.contentHeight(1), contentHeight - extent);
    expect(session(tester).lineRect(1).center.dy, closeTo(160, .01));
    await tester.pumpWidget(const SizedBox.shrink());
  });

  for (final layoutMode in LyricLayoutMode.values) {
    testWidgets('hidden countdown leaves no space in $layoutMode',
        (tester) async {
      final controller = LyricController(document: song());
      addTearDown(controller.dispose);
      final base = quietPreset.copyWith(layoutMode: layoutMode);
      final countdown = config.copyWith(breathDuration: Duration.zero);
      await tester.pumpWidget(Column(children: [
        Expanded(
            child:
                host(controller, preset: base.copyWith(countdown: countdown))),
        Expanded(child: host(controller, preset: base)),
      ]));
      await tester.pumpAndSettle();
      final state = session(tester);
      final reference = session(tester, at: 1);
      final metrics = state.layout!.metrics;
      // Cover future, visible and completed intros/interludes, then seek back.
      for (final position in [
        0,
        6,
        7,
        9,
        10,
        12,
        18,
        19,
        21,
        22,
        30,
        7,
        19,
        6
      ]) {
        controller.setPosition(seconds(position));
        await tester.pumpAndSettle();
        final nextIndex = [7, 9].contains(position)
            ? 0
            : [19, 21].contains(position)
                ? 1
                : null;
        final current = state.layout!;
        final baseline = reference.layout!;
        final extent =
            nextIndex == null ? 0.0 : countdown.height + countdown.spacing;
        expect(current.metrics, same(metrics));
        expect(current.contentHeight(state.activeIndex),
            closeTo(baseline.contentHeight(state.activeIndex) + extent, .01));
        for (var i = 0; i < song().lines.length; i++) {
          expect(
              current.lineTop(i, state.activeIndex),
              closeTo(
                  baseline.lineTop(i, state.activeIndex) +
                      (nextIndex != null && i >= nextIndex ? extent : 0),
                  .01));
        }
        if (nextIndex == null) {
          expect(countdownDots(tester), isEmpty);
          expect(state.scrollController.position.minScrollExtent,
              reference.scrollController.position.minScrollExtent);
          expect(state.scrollController.position.maxScrollExtent,
              reference.scrollController.position.maxScrollExtent);
        } else {
          expect(state.countdownFrame!.nextIndex, nextIndex);
          expect(countdownDots(tester), hasLength(3));
        }
      }
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('countdown insertion reflows an unchanged lyric in $layoutMode',
        (tester) async {
      final controller =
          LyricController(document: song(), initialPosition: seconds(18));
      addTearDown(controller.dispose);
      await tester.pumpWidget(host(controller,
          preset: quietPreset.copyWith(
            layoutMode: layoutMode,
            countdown: config.copyWith(breathDuration: Duration.zero),
            lineTransition: LyricLineTransitions.rise,
            scrollAnimation: const LyricScrollAnimation.fixed(
                duration: Duration(seconds: 1), curve: Curves.linear),
          )));
      await tester.pumpAndSettle();
      final state = session(tester);
      final nextTop = state.lineRect(1).top;
      controller.setPosition(seconds(19));
      await tester.pump();
      expect(state.activeIndex, -1);
      expect(state.lineRect(1).top, closeTo(nextTop, .01));
      expect(state.countdownFrame!.rect.bottom + config.spacing,
          closeTo(nextTop, .01));
      await tester.pumpAndSettle();
      expect(state.countdownFrame!.rect.center.dy, closeTo(120, .01));
      controller.setPosition(seconds(22));
      await tester.pumpAndSettle();
      expect(state.hasCountdown, isFalse);
      expect(state.lineRect(1).center.dy, closeTo(120, .01));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }

  testWidgets('mode and document switches do not use stale countdown geometry',
      (tester) async {
    final controller = LyricController(document: song())
      ..setPosition(seconds(15));
    addTearDown(controller.dispose);
    for (final mode in [
      LyricDisplayMode.activeLine,
      LyricDisplayMode.scrollable,
      LyricDisplayMode.activeLine,
      LyricDisplayMode.scrollable
    ]) {
      await tester.pumpWidget(host(controller,
          preset: quietPreset.copyWith(countdown: config, displayMode: mode)));
      await tester.pumpAndSettle();
      expect(session(tester).hasCountdown, isTrue);
      expect(tester.takeException(), isNull);
    }
    controller.loadDocument(LyricDocument(lines: [
      for (var i = 0; i < 10; i++) line(i, text: ''),
      line(30),
    ]));
    await tester.pumpAndSettle();
    controller.setPosition(seconds(20));
    await tester.pumpAndSettle();
    expect(session(tester).countdownFrame!.nextIndex, 10);
    expect(session(tester).hasCountdown, isTrue);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('dots dim in sequence and fit narrow RTL views', (tester) async {
    final controller = LyricController(document: song())
      ..setPosition(seconds(5));
    addTearDown(controller.dispose);
    await tester.pumpWidget(host(controller,
        size: const Size(80, 200),
        direction: TextDirection.rtl,
        preset: quietPreset.copyWith(
            countdown: const LyricCountdown(
          dotCount: 4,
          dotDuration: Duration(seconds: 10),
          dotSize: 20,
          dotSpacing: 10,
          color: Color(0xFFFFFFFF),
          inactiveColor: Color(0xFF000000),
        ))));
    await tester.pumpAndSettle();
    final dots = countdownDots(tester);
    expect(dots, hasLength(4));
    expect(dots.first.color, const Color(0xFF000000));
    expect(dots.last.color, const Color(0xFFFFFFFF));
    final rect = session(tester).countdownFrame!.rect;
    for (final dot in dots) {
      expect(dot.center.dx - dot.radius, greaterThanOrEqualTo(rect.left));
      expect(dot.center.dx + dot.radius, lessThanOrEqualTo(rect.right));
      expect(dot.radius, lessThan(10));
    }
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('explicit fade direction is physical and default follows text',
      (tester) async {
    final controller =
        LyricController(document: song(), initialPosition: seconds(5));
    addTearDown(controller.dispose);
    for (final ambient in TextDirection.values) {
      for (final direction in LyricCountdownDirection.values) {
        await tester.pumpWidget(host(
          controller,
          direction: ambient,
          preset: quietPreset.copyWith(
              countdown: config.copyWith(
            direction: direction,
            dotDuration: seconds(10),
            breathDuration: Duration.zero,
            color: const Color(0xFFFFFFFF),
            inactiveColor: const Color(0xFF000000),
          )),
        ));
        await tester.pumpAndSettle();
        final dots = countdownDots(tester);
        final ltr = direction == LyricCountdownDirection.leftToRight ||
            (direction == LyricCountdownDirection.startToEnd &&
                ambient == TextDirection.ltr);
        expect(dots.first.center.dx < dots.last.center.dx, ltr);
        expect(dots.first.color, const Color(0xFF000000));
        expect(dots.last.color, const Color(0xFFFFFFFF));
      }
    }
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}

class _CountdownSource implements LyricProgressSource {
  final events = StreamController<void>.broadcast(sync: true);
  Future<void> dispose() => events.close();
  @override
  Duration position = Duration.zero;
  @override
  bool isAdvancing = false;
  @override
  Stream<void> get changes => events.stream;
}
