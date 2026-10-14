import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_lyric/flutter_lyric.dart';
import 'package:flutter_lyric/src/rendering/lyric_word_motion.dart';
import 'apple_music_test_support.dart';
import 'test_support.dart' as support;

void main() {
  testWidgets('far seeks discard interrupted scroll lag in both directions',
      (tester) async {
    final controller = LyricController(document: support.lines());
    addTearDown(controller.dispose);
    const style = AppleMusicLyricStyle(
        characterFloatAmplitude: 0,
        resumeDelay: null,
        selectionSnapMode: LyricSelectionSnapMode.none);
    await tester.pumpWidget(host(controller, style: style));
    await tester.pumpAndSettle();
    final s = session(tester);
    final layout = s.layout!;
    double target(int index) =>
        layout.offsetFor(index, style.activeAnchor, s.size.height);

    for (final indices in [
      [1, 20],
      [21, 0],
    ]) {
      final start = s.scrollY;
      final near = indices[0];
      final far = indices[1];
      expect((target(near) - start).abs(), lessThan(s.size.height));
      controller.setPosition(Duration(seconds: near));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(s.scrollY, greaterThan(start));
      expect(s.scrollY, lessThan(target(near)));
      expect(s.visibleIndices.any((i) => s.displacement(i).abs() > .01), true);

      expect((target(far) - s.scrollY).abs(), greaterThan(s.size.height));
      controller.setPosition(Duration(seconds: far));
      expect(s.scrollY, closeTo(target(far), .001));
      expect(
          List.generate(layout.lines.length, s.displacement), everyElement(0));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(s.scrollY, closeTo(target(far), .001));
      expect(
          List.generate(layout.lines.length, s.displacement), everyElement(0));
      await tester.pumpAndSettle();
      expect(s.following, true);
      expect(s.layout, same(layout));
    }
  });

  testWidgets('scroll commands animate up to one screen and jump beyond it',
      (tester) async {
    final controller = LyricController(
        document: LyricDocument(
            lines: List.generate(
                20,
                (i) =>
                    LyricLine(start: Duration(seconds: i), text: 'Line $i'))));
    addTearDown(controller.dispose);
    final style = quiet.copyWith(
        textStyle: const TextStyle(fontFamily: 'Ahem', fontSize: 20, height: 1),
        lineSpacing: 40,
        lineAnimation:
            const LyricAnimation(duration: Duration(milliseconds: 250)),
        scrollAnimation: const LyricScrollAnimation.fixed(
            duration: Duration(milliseconds: 500)),
        maxLineLag: 64,
        waveAmplitude: 12);
    await tester.pumpWidget(host(controller, style: style));
    await tester.pumpAndSettle();
    final s = session(tester);
    double target(int index) =>
        s.layout!.offsetFor(index, style.selectionAnchor, s.size.height);
    final start = s.scrollY;
    expect(target(6) - start, s.size.height);

    var completed = false;
    final moving = controller.scrollToLine(6).then((_) => completed = true);
    await tester.pump();
    expect(completed, false);
    await tester.pump(const Duration(milliseconds: 100));
    expect(s.scrollY, inExclusiveRange(start, target(6)));
    await tester.pumpAndSettle();
    await moving;
    expect(s.scrollY, closeTo(target(6), .001));

    await controller.resumeFollow(animate: false);
    await tester.pumpAndSettle();
    expect(target(7) - s.scrollY, greaterThan(s.size.height));
    completed = false;
    final jumping = controller.scrollToLine(7).then((_) => completed = true);
    await tester.pump();
    expect(completed, true);
    await jumping;
    expect(s.scrollY, closeTo(target(7), .001));
    expect(s.following, false);
    expect(s.selectedIndex, 7);
    expect(s.visibleIndices.map(s.displacement), everyElement(0));

    completed = false;
    final resuming = controller.resumeFollow().then((_) => completed = true);
    await tester.pump();
    expect(completed, true);
    await resuming;
    expect(s.scrollY, closeTo(start, .001));
    expect(s.following, true);
    expect(s.selectedIndex, isNull);
    expect(s.visibleIndices.map(s.displacement), everyElement(0));
    expect(controller.position, Duration.zero);
    await tester.pumpAndSettle();
  });

  test('float travels smoothly above and below zero within its amplitude', () {
    const style = AppleMusicLyricStyle();
    double sample(int ms, int character) =>
        style.characterFloatAmplitude *
        lyricCharacterFloat(
            Duration(milliseconds: ms),
            style.characterFloatPeriod,
            style.characterFloatStagger,
            character,
            0);
    var min = double.infinity;
    var max = 0.0;
    var maxNeighborDelta = 0.0;
    var sum = 0.0;
    var samples = 0;
    for (var ms = 0; ms < 60000; ms += 16) {
      final value = sample(ms, 0);
      if (value < min) min = value;
      if (value > max) max = value;
      expect(
          value,
          inInclusiveRange(
              -style.characterFloatAmplitude, style.characterFloatAmplitude));
      // No jumps at cycle seams, including when a delayed phase is negative.
      expect((sample(ms + 16, 0) - value).abs(),
          lessThan(style.characterFloatAmplitude * .04));
      final neighborDelta = (sample(ms, 1) - value).abs();
      if (neighborDelta > maxNeighborDelta) maxNeighborDelta = neighborDelta;
      expect(neighborDelta, lessThan(.5));
      if (ms >= 1400) {
        sum += value;
        samples++;
        expect(sample(ms + style.characterFloatStagger.inMilliseconds, 1),
            closeTo(value, 1e-9));
      }
    }
    expect(sample(0, 0), 0);
    expect(min, lessThan(-style.characterFloatAmplitude * .9));
    expect(max, greaterThan(style.characterFloatAmplitude * .9));
    expect(sum / samples, closeTo(0, style.characterFloatAmplitude * .05));
    expect(maxNeighborDelta, greaterThan(.01));
    final cycles = List.generate(6,
        (i) => sample(2000 + i * style.characterFloatPeriod.inMilliseconds, 0));
    expect(cycles.toSet().length, 6);
    expect((cycles[0] - cycles[1]).abs(), greaterThan(.002));
  });

  test('completed pop remains the center of the signed float range', () {
    const style = AppleMusicLyricStyle();
    double combined(int ms) {
      final elapsed = Duration(milliseconds: ms);
      return style.characterFloatAmplitude *
              lyricCharacterFloat(elapsed, style.characterFloatPeriod,
                  style.characterFloatStagger, 0, 0) +
          style.wordLift *
              lyricWordPop(
                  elapsed, const Duration(seconds: 2), style.wordPopDuration);
    }

    var min = double.infinity;
    var max = double.negativeInfinity;
    for (var ms = 3000; ms < 30000; ms += 16) {
      final value = combined(ms);
      if (value < min) min = value;
      if (value > max) max = value;
      expect(
          value,
          inInclusiveRange(style.wordLift - style.characterFloatAmplitude,
              style.wordLift + style.characterFloatAmplitude));
    }
    expect(min, lessThan(style.wordLift - style.characterFloatAmplitude * .9));
    expect(
        max, greaterThan(style.wordLift + style.characterFloatAmplitude * .9));
  });

  test('Word Pop rises monotonically then holds, independent of float', () {
    const start = Duration(seconds: 3);
    const duration = Duration(milliseconds: 500);
    expect(lyricWordPop(Duration.zero, start, duration), 0);
    expect(lyricWordPop(start, start, duration), 0);
    expect(
        lyricWordPop(
            start + const Duration(milliseconds: 250), start, duration),
        .5);
    var previous = 0.0;
    for (var ms = 0; ms <= 500; ms += 10) {
      final value =
          lyricWordPop(start + Duration(milliseconds: ms), start, duration);
      expect(value, inInclusiveRange(previous, 1));
      previous = value;
    }
    expect(lyricWordPop(start + duration, start, duration), 1);
    expect(lyricWordPop(const Duration(seconds: 10), start, duration), 1);
    expect(lyricWordPop(start + duration, start, Duration.zero), 0);
  });

  testWidgets(
      'pop height and float range remain independent and release on exit',
      (tester) async {
    final controller = LyricController(
        document: LyricDocument(lines: [
          LyricLine(start: Duration.zero, text: 'A', words: const [
            LyricWord(
                text: 'A', start: Duration.zero, end: Duration(seconds: 10)),
          ]),
          LyricLine(start: const Duration(seconds: 10), text: 'B'),
        ]),
        initialPosition: const Duration(seconds: 2));
    addTearDown(controller.dispose);
    final style = quiet.copyWith(
        wordLift: 6,
        characterFloatAmplitude: 1,
        characterFloatMode: LyricFloatMode.all);
    await tester.pumpWidget(host(controller, style: style));
    await tester.pump(const Duration(seconds: 2));
    final s = session(tester);
    double pop() => s.wordPopLift(0, s.layout!.lines.first.segments.single);
    final drift = s.characterFloatLift(0, 0);
    expect(drift.abs(), greaterThan(.1));
    expect(pop(), 6);
    await tester.pumpWidget(
        host(controller, style: style.copyWith(characterFloatAmplitude: 3)));
    expect(pop(), 6);
    expect(s.characterFloatLift(0, 0), closeTo(drift * 3, 1e-9));
    await tester
        .pumpWidget(host(controller, style: style.copyWith(wordLift: 9)));
    expect(pop(), 9);
    expect(s.characterFloatLift(0, 0), closeTo(drift, 1e-9));
    await tester.pumpWidget(
        host(controller, style: style.copyWith(characterFloatAmplitude: 0)));
    expect(pop(), 6);
    expect(s.characterFloatLift(0, 0), 0);
    await tester.pumpWidget(host(controller, style: style));
    controller.setPosition(const Duration(seconds: 10));
    await tester.pump();
    expect(pop(), 0);
    expect(s.characterFloatLift(0, 0), 0);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  test('layout reserves space below the baseline for signed float', () {
    final doc = LyricDocument(lines: [
      LyricLine(start: Duration.zero, text: 'A', translation: 'Translation'),
      LyricLine(start: const Duration(seconds: 2), text: 'B'),
    ]);
    final style =
        quiet.copyWith(characterFloatAmplitude: 8, translationSpacing: 0);
    final layout = appleLayout(doc, style, 400);
    addTearDown(layout.dispose);
    final first = layout.lines.first;
    expect(
        first.translationY - (style.textMotionExtent + first.text.height), 8);
    final last = layout.lines.last;
    expect(last.height - (style.textMotionExtent + last.text.height), 8);
  });

  test('float geometry splits timed words into whole graphemes and is lazy',
      () {
    const content = '你👨‍👩‍👧‍👦e\u0301 A';
    final layout = appleLayout(
        LyricDocument(lines: [
          LyricLine(start: Duration.zero, text: content, words: const [
            LyricWord(
                text: content, start: Duration.zero, end: Duration(seconds: 4)),
          ]),
          LyricLine(start: const Duration(seconds: 4), text: '未激活'),
        ]),
        const AppleMusicLyricStyle(),
        400);
    addTearDown(layout.dispose);
    final line = layout.lines.first;
    expect(line.debugCharactersComputed, false);
    expect(
        line.characters
            .map((c) => content.substring(c.startOffset, c.endOffset)),
        ['你', '👨‍👩‍👧‍👦', 'e\u0301', ' ', 'A']);
    expect(
        line.characters
            .every((c) => identical(c.segment, line.segments.single)),
        true);
    expect(line.characters, same(line.characters));
    expect(layout.lines.last.debugCharactersComputed, false);
  });

  testWidgets('float continues at fixed playback without layout or UI rebuilds',
      (tester) async {
    final controller = LyricController(document: support.lines());
    addTearDown(controller.dispose);
    final style = quiet.copyWith(
        characterFloatAmplitude: 1.8, characterFloatMode: LyricFloatMode.all);
    await tester.pumpWidget(host(controller, style: style));
    await tester.pump(const Duration(seconds: 1));
    final s = session(tester);
    final layout = s.layout;
    final presentation = s.presentation.value;
    final lift = s.characterFloatLift(0, 0);
    final top = s.lineTop(0);
    await tester.pump(const Duration(milliseconds: 700));
    expect(s.characterFloatLift(0, 0), isNot(closeTo(lift, .01)));
    expect(s.characterFloatLift(1, 0), 0);
    expect(controller.position, Duration.zero);
    expect(s.layout, same(layout));
    expect(s.lineTop(0), top);
    expect(s.presentation.value, presentation);
    // Timing controls do not remeasure or reset the continuous float clock.
    await tester.pumpWidget(host(controller,
        style: style.copyWith(
            wordPopDuration: const Duration(milliseconds: 800),
            characterFloatPeriod: const Duration(seconds: 5))));
    expect(s.layout, same(layout));
    await tester.pumpWidget(const SizedBox.shrink());
    expect(tester.binding.transientCallbackCount, 0);
  });

  testWidgets('float stops for reduced motion, hidden/offscreen/empty views',
      (tester) async {
    final controller = LyricController(document: support.lines(count: 100));
    addTearDown(controller.dispose);
    final style = quiet.copyWith(
        characterFloatAmplitude: 1.8, characterFloatMode: LyricFloatMode.all);
    await tester.pumpWidget(host(controller, style: style));
    await tester.pump(const Duration(seconds: 1));
    final s = session(tester);
    expect(s.characterFloatLift(0, 0), greaterThan(0));
    await tester.pumpWidget(host(controller, style: style, reduced: true));
    await tester.pumpAndSettle();
    expect(s.characterFloatLift(0, 0), 0);
    expect(tester.binding.transientCallbackCount, 0);
    await tester.pumpWidget(host(controller, style: style, enabled: false));
    await tester.pumpAndSettle();
    expect(tester.binding.transientCallbackCount, 0);
    await tester.pumpWidget(host(controller, style: style));
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.binding.transientCallbackCount, greaterThan(0));
    await controller.scrollToLine(90, animate: false);
    await tester.pumpAndSettle();
    expect(tester.binding.transientCallbackCount, 0);
    await controller.resumeFollow(animate: false);
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.binding.transientCallbackCount, greaterThan(0));
    controller.clear();
    await tester.pumpAndSettle();
    expect(tester.binding.transientCallbackCount, 0);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
      'either float amplitude or period can independently stop its clock',
      (tester) async {
    final controller = LyricController(document: support.lines());
    addTearDown(controller.dispose);
    for (final style in [
      quiet.copyWith(characterFloatAmplitude: 0),
      quiet.copyWith(
          characterFloatAmplitude: 2, characterFloatPeriod: Duration.zero),
    ]) {
      await tester.pumpWidget(host(controller, style: style));
      await tester.pumpAndSettle();
      expect(session(tester).characterFloatLift(0, 0), 0);
      expect(tester.binding.transientCallbackCount, 0);
    }
  });
}
