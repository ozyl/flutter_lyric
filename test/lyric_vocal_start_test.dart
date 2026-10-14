import 'package:flutter/widgets.dart';
import 'package:flutter_lyric/flutter_lyric.dart';
import 'package:flutter_lyric/src/model/lyric_gap.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_support.dart';

Duration seconds(int value) => Duration(seconds: value);

LyricDocument creditsSong({Duration? vocalStart}) => LyricDocument(
      vocalStart: vocalStart,
      lines: [
        // Credit timing may cover the whole intro, or even overlap the vocals.
        LyricLine(start: Duration.zero, end: seconds(50), text: 'Composer'),
        LyricLine(start: seconds(7), end: seconds(10), text: 'Artist:', words: [
          LyricWord(text: 'Artist:', start: seconds(7), end: seconds(10)),
        ]),
        LyricLine(start: seconds(10), end: seconds(12), text: 'First vocal'),
        LyricLine(start: seconds(22), end: seconds(25), text: 'Next vocal'),
      ],
    );

void main() {
  const config = LyricCountdown(breathDuration: Duration(seconds: 120));

  test('vocal start overrides intro credits without changing their timing', () {
    final original = creditsSong();
    expect(LyricGapTimeline(original).at(seconds(8), config), isNull);
    final document = original.copyWith(vocalStart: seconds(10));
    final timeline = LyricGapTimeline(document);
    final intro = timeline.at(seconds(8), config)!;
    expect(intro.isIntro, isTrue);
    expect(intro.start, Duration.zero);
    expect(intro.end, seconds(10));
    expect(intro.nextIndex, 2);
    expect(timeline.at(Duration.zero, config), same(intro));
    expect(timeline.at(seconds(6), config), same(intro));
    expect(timeline.at(seconds(10), config), isNull);
    expect(document.lines[0], same(original.lines[0]));
    expect(document.lines[1].words, same(original.lines[1].words));
    expect(document.lines[0].end, seconds(50));
    final interlude = timeline.at(seconds(15), config)!;
    expect(interlude.isIntro, isFalse);
    expect(interlude.start, seconds(12));
    expect(interlude.end, seconds(22));
    expect(interlude.nextIndex, 3);
  });

  test(
      'vocal-start credits can supply the countdown but not extra time before zero',
      () {
    final timeline = LyricGapTimeline(creditsSong(vocalStart: seconds(10)));
    final countdown = config.copyWith(breathDuration: Duration.zero);
    expect(timeline.at(seconds(6), countdown), isNull);
    expect(timeline.at(seconds(7), countdown)!.displayStart(countdown),
        seconds(7));
    expect(timeline.at(seconds(8), config.copyWith(dotDuration: seconds(11))),
        isNull);
    expect(timeline.at(seconds(15), config.copyWith(dotDuration: seconds(11))),
        isNull);
    expect(timeline.at(seconds(8), const LyricCountdown.none()), isNull);
    expect(timeline.at(seconds(-1), config), isNull);
    expect(timeline.at(seconds(30), config), isNull);
  });

  test('hinted intros span zero to vocals regardless of credit timing', () {
    for (final times in [
      [7916, 11438],
      [39990, 59997],
    ]) {
      final end = Duration(milliseconds: times[1]);
      for (final creditStart in [times[0], times[1] - 1]) {
        final document = LyricDocument.parse(
          '[0,$creditStart]Title(0,$creditStart)\n'
          '[$creditStart,${times[1]}]Credit($creditStart,${times[1]})\n'
          '[${times[1]},1000]Vocal(${times[1]},1000)',
          vocalStart: end,
        );
        final timeline = LyricGapTimeline(document);
        final gap = timeline.at(Duration.zero, config)!;
        expect(gap.start, Duration.zero);
        expect(gap.end, end);
        expect(gap.nextIndex, 2);
        final lastThree = config.copyWith(
          breathDuration: Duration.zero,
        );
        final displayStart = end - seconds(3);
        expect(timeline.at(displayStart, lastThree), same(gap));
        expect(
            timeline.at(
                displayStart - const Duration(milliseconds: 1), lastThree),
            isNull);
        expect(timeline.at(end, config), isNull);
      }
    }
    final noCredit = LyricGapTimeline(LyricDocument(lines: [
      LyricLine(start: seconds(10), text: 'Vocal'),
    ], vocalStart: seconds(10)));
    expect(noCredit.at(Duration.zero, config)!.start, Duration.zero);
  });

  test('short hinted and inferred intros both require the entire dot duration',
      () {
    final document = LyricDocument(lines: [
      LyricLine(start: Duration.zero, end: seconds(2), text: 'Credit'),
      LyricLine(start: seconds(2), end: seconds(3), text: 'First vocal'),
      LyricLine(start: seconds(5), end: seconds(6), text: 'Next vocal'),
    ]);
    for (final hint in [null, seconds(2)]) {
      final timeline = LyricGapTimeline(document.copyWith(vocalStart: hint));
      expect(timeline.at(Duration.zero, config), isNull);
      expect(timeline.at(seconds(1), config), isNull);
      expect(timeline.at(seconds(3), config), isNull);
    }
    final timeline =
        LyricGapTimeline(document.copyWith(vocalStart: seconds(2)));
    final shorter = config.copyWith(dotDuration: seconds(2));
    expect(
        timeline
            .at(Duration.zero, shorter)!
            .dotProgress(Duration.zero, shorter),
        0);
    expect(timeline.at(seconds(2), shorter), isNull);
  });

  test('provider millisecond hints locate both QRC and truncated LRC vocals',
      () {
    final hint = const Duration(milliseconds: 59997);
    for (final text in [
      '[39990,20000]Composer(39990,20000)\n'
          '[59997,1667]First vocal(59997,1667)\n'
          '[61664,1000]Next vocal(61664,1000)',
      '[00:39.99]Composer\n[00:59.99]First vocal\n[01:01.66]Next vocal',
    ]) {
      final document = LyricDocument.parse(text, vocalStart: hint);
      final intro = LyricGapTimeline(document).at(seconds(58), config)!;
      expect(intro.nextIndex, 1);
      expect(intro.isIntro, isTrue);
      expect(intro.end, document.lines[1].start);
    }
  });

  test('empty or unmatched vocal starts do not create phantom countdowns', () {
    for (final document in [
      LyricDocument(lines: [], vocalStart: seconds(10)),
      LyricDocument(lines: [
        LyricLine(start: Duration.zero, text: 'Credit'),
        LyricLine(start: seconds(10), text: ''),
      ], vocalStart: seconds(10)),
      creditsSong(vocalStart: seconds(30)),
      LyricDocument(lines: [
        LyricLine(start: Duration.zero, text: 'Immediate vocal'),
      ], vocalStart: Duration.zero),
    ]) {
      expect(LyricGapTimeline(document).gaps, isEmpty);
    }
  });

  test('vocal start can be parsed, copied, cleared and loaded', () {
    final document = LyricDocument.parse(
      '[ti:Song]\n[offset:200]\n[00:00]Credit\n[00:10]Vocal',
      translation: '[00:10]Translation',
      parser: LrcParser(),
      vocalStart: seconds(10),
    );
    expect(document.vocalStart, seconds(10));
    expect(document.title, 'Song');
    expect(document.offset, const Duration(milliseconds: 200));
    expect(document.lines.last.translation, 'Translation');
    expect(document.copyWith(offset: seconds(1)).vocalStart, seconds(10));
    expect(document.copyWith(vocalStart: seconds(12)).vocalStart, seconds(12));
    expect(document.copyWith(clearVocalStart: true).vocalStart, isNull);
    expect(
        () => document.copyWith(vocalStart: seconds(10), clearVocalStart: true),
        throwsArgumentError);
    expect(
        () => document.copyWith(vocalStart: seconds(-1)), throwsArgumentError);
    expect(() => LyricDocument(lines: [], vocalStart: seconds(-1)),
        throwsArgumentError);
    final controller = LyricController();
    addTearDown(controller.dispose);
    controller.load('[00:00]Credit\n[00:10]Vocal', vocalStart: seconds(10));
    expect(controller.document!.vocalStart, seconds(10));
    controller.load('[00:00]Another song');
    expect(controller.document!.vocalStart, isNull);
  });

  for (final layoutMode in LyricLayoutMode.values) {
    testWidgets(
        'countdown entry and vocal start use scroll animation in $layoutMode',
        (tester) async {
      final controller = LyricController(
          document: creditsSong(vocalStart: seconds(10)),
          initialPosition: seconds(6));
      addTearDown(controller.dispose);
      final preset = quietPreset.copyWith(
        layoutMode: layoutMode,
        countdown: config.copyWith(breathDuration: Duration.zero),
        lineTransition: LyricLineTransitions.rise,
        scrollAnimation: const LyricScrollAnimation.fixed(
            duration: Duration(seconds: 1), curve: Curves.linear),
      );
      await tester.pumpWidget(host(controller, preset: preset));
      await tester.pumpAndSettle();
      final state = session(tester);
      final metrics = state.layout!.metrics;
      final rowTop = state.lineRect(2).top - config.height - config.spacing;
      final scroll = state.scrollY;
      expect(state.hasCountdown, isFalse);
      controller.setPosition(seconds(7));
      await tester.pump();
      expect(state.scrollY, scroll);
      expect(state.countdownFrame!.rect.top, closeTo(rowTop, .01));
      expect(state.countdownFrame!.rect.center.dy, greaterThan(140));
      await tester.pump(); // Start the ticker scheduled after the entry layout.
      await tester.pump(const Duration(milliseconds: 500));
      expect(state.countdownFrame!.rect.center.dy, greaterThan(120));
      expect(state.countdownFrame!.rect.top, lessThan(rowTop));
      await tester.pumpAndSettle();
      expect(state.countdownFrame!.rect.center.dy, closeTo(120, .01));
      expect(state.layout!.metrics, same(metrics));
      final vocalTop = state.lineRect(2).top;
      final vocalScroll = state.scrollY;
      controller.setPosition(seconds(10));
      await tester.pump();
      expect(state.hasCountdown, isFalse);
      expect(countdownDots(tester), isEmpty);
      expect(state.scrollY, vocalScroll);
      expect(state.lineRect(2).top, closeTo(vocalTop, .01));
      await tester.pumpAndSettle();
      expect(state.lineRect(2).center.dy, closeTo(120, .01));
      expect(state.layout!.metrics, same(metrics));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets(
        'browsing during credit reflow keeps Canvas dots continuous in $layoutMode',
        (tester) async {
      final controller = LyricController(
          document: LyricDocument(
        vocalStart: seconds(10),
        lines: [
          LyricLine(start: Duration.zero, text: 'Composed by ${'Name ' * 20}'),
          LyricLine(start: seconds(7), text: 'Produced by Artist'),
          LyricLine(start: seconds(10), text: 'First vocal'),
        ],
      ));
      addTearDown(controller.dispose);
      await tester.pumpWidget(host(controller,
          preset: quietPreset.copyWith(
            layoutMode: layoutMode,
            activeTextStyle: const TextStyle(fontSize: 30),
            scrollAnimation: const LyricScrollAnimation.fixed(),
            countdown: config,
          )));
      await tester.pumpAndSettle();
      controller.setPosition(seconds(7));
      await tester.pump();
      final state = session(tester);
      final center = countdownDots(tester).first.center;
      final scroll = state.scrollY;
      state.beginBrowsing();
      await tester.pump();
      expect(countdownDots(tester).first.center, center);
      state.scrollController.jumpTo(scroll + 12);
      await tester.pump();
      expect(countdownDots(tester).first.center, center - const Offset(0, 12));
      await tester.pumpAndSettle();
      await controller.resumeFollow(animate: false);
      await tester.pumpAndSettle();
      expect(countdownDots(tester).first.center.dy, closeTo(120, .01));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets(
        'countdown shares lyric flow during credit reflow and waves in $layoutMode',
        (tester) async {
      final document = LyricDocument(vocalStart: seconds(10), lines: [
        LyricLine(start: Duration.zero, text: 'Composed by ${'Name ' * 20}'),
        LyricLine(start: seconds(7), text: 'Produced by Artist'),
        LyricLine(start: seconds(10), text: 'First vocal'),
      ]);
      final controller = LyricController(document: document);
      addTearDown(controller.dispose);
      final preset = quietPreset.copyWith(
        layoutMode: layoutMode,
        activeTextStyle: const TextStyle(fontSize: 30),
        lineTransition: LyricLineTransitions.rise,
        scrollAnimation: const LyricScrollAnimation.fixed(),
        lineMotion: const LyricLineMotion(
          delay: Duration(milliseconds: 35),
          maxDelay: Duration(milliseconds: 140),
          waveDuration: Duration(milliseconds: 600),
          waveAmplitude: 12,
          maxLag: 64,
        ),
        countdown: config,
      );
      await tester.pumpWidget(host(controller, preset: preset));
      await tester.pumpAndSettle();
      final state = session(tester);
      controller.setPosition(seconds(7));
      await tester.pump();
      for (var sample = 0; sample < 50; sample++) {
        final frame = state.countdownFrame!;
        expect(frame.rect.bottom + config.spacing,
            closeTo(state.lineRect(frame.nextIndex).top, .01));
        expect(countdownDots(tester), hasLength(3));
        await tester.pump(const Duration(milliseconds: 16));
      }
      await tester.pumpAndSettle();
      expect(state.countdownFrame!.rect.center.dy, closeTo(120, .01));
      expect(controller.activeLineIndex, 1);
      controller.setPosition(seconds(10));
      await tester.pumpAndSettle();
      expect(session(tester).hasCountdown, isFalse);
      expect(state.lineRect(2).center.dy, closeTo(120, .01));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }

  for (final mode in LyricDisplayMode.values) {
    for (final layoutMode in LyricLayoutMode.values) {
      testWidgets('credit intro follows seeks and offsets in $mode/$layoutMode',
          (tester) async {
        final document = creditsSong(vocalStart: seconds(10));
        final controller =
            LyricController(document: document, initialPosition: seconds(6));
        addTearDown(controller.dispose);
        final preset = quietPreset.copyWith(
          countdown: config.copyWith(breathDuration: Duration.zero),
          displayMode: mode,
          layoutMode: layoutMode,
        );
        await tester.pumpWidget(host(controller, preset: preset));
        await tester.pumpAndSettle();
        final state = session(tester);
        expect(session(tester).hasCountdown, isFalse);
        expect(controller.activeLineIndex, 0);
        if (mode == LyricDisplayMode.scrollable) {
          expect(state.lineRect(0).center.dy, closeTo(120, .01));
          expect(state.lineRect(2).center.dy, greaterThan(120));
        }
        controller.setPosition(seconds(7));
        await tester.pumpAndSettle();
        expect(session(tester).hasCountdown, isTrue);
        expect(state.countdownFrame!.nextIndex, 2);
        expect(state.countdownFrame!.isIntro, isTrue);
        expect(state.countdownFrame!.remaining, seconds(3));
        expect(state.countdownFrame!.rect.center.dy, closeTo(120, .01));
        expect(controller.activeLineIndex, 1);
        if (mode == LyricDisplayMode.scrollable) {
          expect(state.countdownFrame!.rect.bottom,
              lessThan(state.lineRect(2).top));
        } else {
          expect(state.visibleIndices, isEmpty);
        }
        controller.setPosition(seconds(10));
        await tester.pumpAndSettle();
        expect(session(tester).hasCountdown, isFalse);
        expect(controller.activeLineIndex, 2);
        if (mode == LyricDisplayMode.scrollable) {
          expect(state.lineRect(2).center.dy, closeTo(120, .01));
        }
        controller.setPosition(seconds(8));
        await tester.pumpAndSettle();
        expect(state.countdownFrame!.remaining, seconds(2));
        controller.loadDocument(document.copyWith(offset: seconds(1)));
        await tester.pumpAndSettle();
        expect(state.countdownFrame!.remaining, seconds(1));
        expect(state.lineDetails(state.countdownFrame!.nextIndex).seekPosition,
            seconds(9));
        controller.timeOffset = seconds(1);
        await tester.pumpAndSettle();
        expect(session(tester).hasCountdown, isFalse);
        controller.timeOffset = Duration.zero;
        await tester.pumpAndSettle();
        await tester.pump(seconds(4));
        expect(state.countdownFrame!.remaining, seconds(1));
        if (mode == LyricDisplayMode.scrollable) {
          await controller.scrollToLine(1, animate: false);
          await tester.pumpAndSettle();
          expect(state.following, isFalse);
          expect(state.hasCountdown, isTrue);
          await controller.resumeFollow(animate: false);
          await tester.pumpAndSettle();
          expect(session(tester).hasCountdown, isTrue);
        }
        controller.loadDocument(document.copyWith(clearVocalStart: true));
        await tester.pumpAndSettle();
        expect(session(tester).hasCountdown, isFalse);
        expect(controller.document!.lines[1].words!.single.end, seconds(10));
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      });
    }
  }
}
