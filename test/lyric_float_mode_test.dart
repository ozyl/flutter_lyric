import 'dart:ui' as ui;
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_lyric/flutter_lyric.dart';
import 'package:flutter_lyric/src/rendering/lyric_word_layout.dart';
import 'apple_music_test_support.dart';

void main() {
  test(
      'float mode defaults and compatibility conversion retain value semantics',
      () {
    const effects = LyricWordEffects(floatAmplitude: 2);
    expect(effects.floatMode, LyricFloatMode.highlighted);
    expect(
        effects,
        isNot(const LyricWordEffects(
            floatAmplitude: 2, floatMode: LyricFloatMode.all)));
    expect(LyricPresets.appleMusic.wordEffects.floatMode,
        LyricFloatMode.highlighted);
    expect(
        LyricPresets.drift.wordEffects.floatMode, LyricFloatMode.highlighted);
    const style = AppleMusicLyricStyle();
    expect(style.characterFloatMode, LyricFloatMode.highlighted);
    final all = style.copyWith(characterFloatMode: LyricFloatMode.all);
    expect(all, isNot(style));
    expect(all.copyWith(), all);
    expect(all.copyWith().hashCode, all.hashCode);
    expect(all.toPreset().wordEffects.floatMode, LyricFloatMode.all);
    expect(all.copyWith(characterFloatMode: LyricFloatMode.highlighted), style);
  });

  for (final direction in [TextDirection.ltr, TextDirection.rtl]) {
    test('float follows wrapped highlight geometry and tail in $direction', () {
      final boxes = [
        ui.TextBox.fromLTRBD(0, 0, 40, 10, direction),
        ui.TextBox.fromLTRBD(0, 10, 40, 20, direction),
      ];
      final segment = LyricWordSegment(
          0,
          4,
          Duration.zero,
          const Duration(seconds: 1),
          boxes,
          boxes.map((b) => b.toRect()).toList());
      final rtl = direction == TextDirection.rtl;
      LyricWordCharacter character(int ordinal, double top) =>
          LyricWordCharacter(
              ordinal,
              ordinal,
              ordinal + 1,
              [
                Rect.fromLTRB(rtl ? 20 : 0, top, rtl ? 40 : 20, top + 10),
              ],
              segment);
      final first = character(0, 0);
      final wrapped = character(2, 10);
      expect(first.highlightProgress(Duration.zero, 0), 0);
      expect(first.highlightProgress(const Duration(milliseconds: 125), 0), .5);
      expect(first.highlightProgress(const Duration(milliseconds: 250), 0), 1);
      expect(
          wrapped.highlightProgress(const Duration(milliseconds: 500), 0), 0);
      expect(
          wrapped.highlightProgress(const Duration(milliseconds: 625), 0), .5);
      expect(
          wrapped.highlightProgress(const Duration(milliseconds: 750), 0), 1);
      // A 20px soft tail reaches the first 20px character at 200ms,
      // and completely covers it at 400ms (total travel is 80 + 20px).
      expect(
          first.highlightProgress(const Duration(milliseconds: 200), 20), .5);
      expect(first.highlightProgress(const Duration(milliseconds: 400), 20), 1);
      expect(
          wrapped.highlightProgress(const Duration(milliseconds: 400), 20), 0);
      expect(wrapped.highlightProgress(const Duration(seconds: 1), 20), 1);
    });
  }

  testWidgets(
      'default floats reached graphemes and mode switches without layout',
      (tester) async {
    final controller = LyricController(
        document: LyricDocument(lines: [
      LyricLine(start: Duration.zero, text: 'ABCD X', words: const [
        LyricWord(
            text: 'ABCD',
            start: Duration(seconds: 1),
            end: Duration(seconds: 5)),
      ]),
    ]));
    addTearDown(controller.dispose);
    final style = quiet.copyWith(
        characterFloatAmplitude: 2,
        highlight: const LyricHighlight.solid(Color(0xFFFFFFFF)));
    await tester.pumpWidget(host(controller, style: style));
    await tester.pumpAndSettle();
    final s = session(tester);
    final layout = s.layout;
    final line = layout!.wordLine(0, true);
    expect(line.characters.map((c) => s.characterFloatLift(0, c.ordinal)),
        everyElement(0));
    expect(tester.binding.transientCallbackCount, 0);

    controller.setPosition(const Duration(milliseconds: 2500));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1700));
    final first = s.characterFloatLift(0, 0);
    final partial = s.characterFloatLift(0, 1);
    expect(first.abs(), greaterThan(.01));
    expect(partial.abs(), greaterThan(.01));
    for (var i = 2; i < line.characters.length; i++) {
      expect(s.characterFloatLift(0, i), 0);
    }
    await tester.pumpWidget(host(controller,
        style: style.copyWith(characterFloatMode: LyricFloatMode.all)));
    expect(s.layout, same(layout));
    expect(s.characterFloatLift(0, 0), closeTo(first, 1e-9));
    expect(s.characterFloatLift(0, 1), closeTo(partial * 2, 1e-9));
    expect(s.characterFloatLift(0, 3).abs(), greaterThan(.01));
    expect(s.characterFloatLift(0, 5).abs(), greaterThan(.01));
    await tester.pumpWidget(host(controller, style: style));
    expect(s.characterFloatLift(0, 3), 0);
    controller.setPosition(Duration.zero);
    await tester.pumpAndSettle();
    expect(s.characterFloatLift(0, 0), 0);
    expect(tester.binding.transientCallbackCount, 0);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
      'simulation gates whole graphemes; untimed highlighted lines float',
      (tester) async {
    final controller = LyricController(
        document: LyricDocument(lines: [
          LyricLine(
              start: Duration.zero,
              end: const Duration(seconds: 3),
              text: 'A👨‍👩‍👧‍👦e\u0301'),
        ]),
        initialPosition: const Duration(milliseconds: 500));
    addTearDown(controller.dispose);
    final style = quiet.copyWith(characterFloatAmplitude: 2);
    await tester.pumpWidget(host(controller, style: style));
    await tester.pump(const Duration(milliseconds: 1700));
    final s = session(tester);
    expect(s.layout!.wordLine(0, true).characters, hasLength(3));
    expect(s.characterFloatLift(0, 0).abs(), greaterThan(.01));
    expect(s.characterFloatLift(0, 1), 0);
    expect(s.characterFloatLift(0, 2), 0);
    final before = s.characterFloatLift(0, 0);
    await tester.pump(const Duration(milliseconds: 500));
    expect(s.characterFloatLift(0, 0), isNot(closeTo(before, .001)));
    expect(controller.position, const Duration(milliseconds: 500));
    controller.setPosition(const Duration(milliseconds: 2500));
    await tester.pump();
    expect(s.characterFloatLift(0, 1).abs(), greaterThan(.01));
    expect(s.characterFloatLift(0, 2).abs(), greaterThan(.01));

    await tester.pumpWidget(
        host(controller, style: style.copyWith(simulateWordTiming: false)));
    expect(s.layout!.wordLine(0, true).segments, isEmpty);
    expect(s.characterFloatLift(0, 2).abs(), greaterThan(.01));
    await tester.pumpWidget(host(controller,
        style: style.copyWith(highlight: const LyricHighlight.none())));
    await tester.pumpAndSettle();
    expect(s.characterFloatLift(0, 0), 0);
    expect(tester.binding.transientCallbackCount, 0);
    await tester.pumpWidget(host(controller,
        style: style.copyWith(
            highlight: const LyricHighlight.none(),
            characterFloatMode: LyricFloatMode.all)));
    await tester.pump(const Duration(milliseconds: 500));
    expect(s.characterFloatLift(0, 2).abs(), greaterThan(.01));
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
