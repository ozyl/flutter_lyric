import 'dart:ui' as ui;
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_lyric/flutter_lyric.dart';
import 'package:flutter_lyric/src/rendering/lyric_viewport.dart';
import 'test_support.dart' as support;
import 'apple_music_test_support.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('style has independent value semantics and nullable clearing', () {
    const original = AppleMusicLyricStyle();
    expect(original, original.copyWith());
    expect(original.hashCode, original.copyWith().hashCode);
    expect(original.blurWhenBrowsing, false);
    final blurredBrowsing = original.copyWith(blurWhenBrowsing: true);
    expect(blurredBrowsing, isNot(original));
    expect(blurredBrowsing.copyWith().blurWhenBrowsing, true);
    expect(blurredBrowsing.copyWith(blurWhenBrowsing: false), original);
    expect(original.copyWith(wordLift: 0), isNot(original));
    expect(original.copyWith(wordPopDuration: Duration.zero), isNot(original));
    expect(original.copyWith(characterFloatAmplitude: 0), isNot(original));
    expect(original.copyWith(characterFloatPeriod: Duration.zero),
        isNot(original));
    expect(original.copyWith(characterFloatStagger: Duration.zero),
        isNot(original));
    expect(original.copyWith(clearResumeDelay: true).resumeDelay, isNull);
    expect(
        () => original.copyWith(
            clearResumeDelay: true, resumeDelay: Duration.zero),
        throwsArgumentError);
  });

  test('simulation preserves graphemes, duplicates and shared source data', () {
    final doc = LyricDocument(lines: [
      LyricLine(start: Duration.zero, text: '你👨‍👩‍👧‍👦e\u0301'),
      LyricLine(start: Duration.zero, text: '重复'),
      LyricLine(start: const Duration(seconds: 3), text: '最后'),
    ]);
    final layout = appleLayout(doc, quiet, 400);
    addTearDown(layout.dispose);
    final first = layout.lines.first.segments;
    expect(first, hasLength(3));
    expect(
        first.map(
            (s) => doc.lines.first.text.substring(s.startOffset, s.endOffset)),
        ['你', '👨‍👩‍👧‍👦', 'e\u0301']);
    expect(first.last.end, const Duration(seconds: 3));
    expect(layout.lines[1].segments.last.end, const Duration(seconds: 3));
    expect(layout.lines.last.segments, isEmpty);
    expect(doc.lines.every((line) => line.words == null), true);
  });

  test('real timing wins, explicit ends work, simulation can be disabled', () {
    final doc = LyricDocument(lines: [
      LyricLine(
          start: Duration.zero,
          end: const Duration(seconds: 3),
          text: 'AB',
          words: [
            const LyricWord(
                text: 'A',
                start: Duration(seconds: 1),
                end: Duration(seconds: 2)),
            const LyricWord(text: 'B', start: Duration(seconds: 2)),
          ]),
      LyricLine(
          start: const Duration(seconds: 4),
          end: const Duration(seconds: 6),
          text: 'CD'),
    ]);
    final layout = appleLayout(doc, quiet, 200);
    final disabled =
        appleLayout(doc, quiet.copyWith(simulateWordTiming: false), 200);
    addTearDown(layout.dispose);
    addTearDown(disabled.dispose);
    expect(
        layout.lines.first.segments.first
            .progress(const Duration(milliseconds: 1500)),
        .5);
    expect(layout.lines.first.segments.last.end, const Duration(seconds: 3));
    expect(layout.lines.last.segments.last.end, const Duration(seconds: 6));
    expect(disabled.lines.first.segments, hasLength(2));
    expect(disabled.lines.last.segments, isEmpty);
  });

  testWidgets('shares playback but isolates browsing and scope',
      (tester) async {
    final controller = LyricController(document: support.lines());
    addTearDown(controller.dispose);
    await tester.pumpWidget(LyricPresetScope(
        preset: LyricPresets.cinema,
        child: host(controller, id: 'apple', compare: true)));
    await tester.pumpAndSettle();
    expect(controller.attachedViewIds, containsAll(['apple', 'ordinary']));
    expect(session(tester).preset, quiet.toPreset());
    await controller.scrollToLine(4, viewId: 'apple', animate: false);
    await tester.pumpAndSettle();
    expect(session(tester).following, false);
    expect(support.session(tester, at: 1).following, true);
    controller.setPosition(const Duration(seconds: 6));
    await tester.pumpAndSettle();
    expect(session(tester).activeIndex, 6);
    expect(support.session(tester, at: 1).activeIndex, 6);
    expect(session(tester).selectedIndex, 4);
    await controller.resumeFollow(viewId: 'apple', animate: false);
    await tester.pumpAndSettle();
    expect(session(tester).following, true);
    await tester.pumpWidget(const SizedBox.shrink());
    expect(controller.hasClients, false);
  });

  testWidgets(
      'animated hit testing emits offset-corrected time without seeking',
      (tester) async {
    final controller = LyricController(
        document: support.lines(offset: const Duration(milliseconds: 100)),
        timeOffset: const Duration(milliseconds: 200));
    addTearDown(controller.dispose);
    final taps = <LyricLineDetails>[];
    final style = quiet.copyWith(waveAmplitude: 12, wordLift: 4);
    await tester.pumpWidget(host(controller, style: style, onTap: taps.add));
    await tester.pumpAndSettle();
    final s = session(tester);
    final origin = tester.getTopLeft(find.byType(LyricViewport));
    await tester.tapAt(origin + s.lineRect(1).center);
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tapAt(origin + s.lineRect(1).center);
    expect(taps.map((t) => t.index), [1, 1]);
    expect(taps.first.seekPosition, const Duration(milliseconds: 700));
    expect(controller.position, Duration.zero);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('switches scale smoothly without remeasuring or rewrapping',
      (tester) async {
    final controller = LyricController(document: support.lines());
    addTearDown(controller.dispose);
    final style = quiet.copyWith(
        inactiveScale: .8,
        lineAnimation: const LyricAnimation(
            duration: Duration(milliseconds: 250), curve: Curves.linear));
    await tester.pumpWidget(host(controller, style: style));
    await tester.pumpAndSettle();
    final s = session(tester);
    final layout = s.layout;
    final height = layout!.height;
    controller.setPosition(const Duration(milliseconds: 500));
    controller.setPosition(const Duration(seconds: 1));
    expect(s.positionFor(0), const Duration(milliseconds: 500));
    await tester.pump();
    expect(s.scaleFor(1), closeTo(.8, .0001));
    await tester.pump(const Duration(milliseconds: 125));
    expect(s.scaleFor(1), closeTo(.9, .0001));
    expect(s.scaleFor(0), closeTo(.9, .0001));
    expect(s.layout, same(layout));
    expect(layout.height, height);
    controller.setPosition(const Duration(seconds: 2));
    expect(s.scaleFor(1), closeTo(.9, .0001));
    await tester.pumpAndSettle();
    expect(s.scaleFor(2), 1);
    expect(s.scaleFor(1), .8);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('animated travel can be interrupted, dragged and resumed',
      (tester) async {
    final controller = LyricController(document: support.lines());
    addTearDown(controller.dispose);
    const style = AppleMusicLyricStyle(
        characterFloatAmplitude: 0,
        resumeDelay: Duration(milliseconds: 500),
        selectionSnapMode: LyricSelectionSnapMode.none);
    await tester.pumpWidget(host(controller, style: style));
    await tester.pumpAndSettle();
    controller.setPosition(const Duration(seconds: 1));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 180));
    final s = session(tester);
    final y = s.lineTop(1);
    controller.setPosition(const Duration(seconds: 2));
    expect(s.lineTop(1), closeTo(y, .01));
    await tester.drag(find.byType(LyricViewport), const Offset(0, -90));
    await tester.pump();
    expect(s.following, false);
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(s.following, true);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
      'reduced motion, hidden views, replacement and disposal settle safely',
      (tester) async {
    final controller = LyricController(document: support.lines());
    final other = LyricController(document: support.lines(count: 2));
    addTearDown(controller.dispose);
    addTearDown(other.dispose);
    await tester.pumpWidget(
        host(controller, style: const AppleMusicLyricStyle(), reduced: true));
    await tester.pumpAndSettle();
    controller.setPosition(const Duration(seconds: 10));
    await tester.pump();
    expect(session(tester).scaleFor(10), 1);
    expect(session(tester).displacement(10), 0);
    final future = controller.scrollToLine(15, animate: true);
    await tester.pumpAndSettle();
    await future;
    await tester.pumpWidget(
        host(controller, style: const AppleMusicLyricStyle(), enabled: false));
    await tester.pump();
    await tester.pumpWidget(host(other));
    await tester.pumpAndSettle();
    expect(controller.hasClients, false);
    expect(other.hasClients, true);
    controller.setPosition(Duration.zero);
    expect(session(tester).controller, same(other));
    await tester.pumpWidget(const SizedBox.shrink());
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'long lyrics paint a bounded window and defer masks and word boxes',
      (tester) async {
    final controller = LyricController(
        document: support.lines(count: 5000),
        initialPosition: const Duration(seconds: 4900));
    addTearDown(controller.dispose);
    await tester
        .pumpWidget(host(controller, style: const AppleMusicLyricStyle()));
    await tester.pump(const Duration(seconds: 1));
    final s = session(tester);
    final layout = s.layout!;
    expect(layout.metrics.where((line) => line.debugSegmentsComputed).length,
        lessThan(3));
    expect(layout.metrics.last.debugWordMaskComputed, false);
    expect(layout.metrics.where((line) => line.debugCharactersComputed).length,
        lessThan(3));
    final recorder = ui.PictureRecorder();
    final painter = s.painter!;
    painter.paint(Canvas(recorder), s.size);
    support.disposeNative(recorder.endRecording());
    expect(painter.debugPaintedLines, lessThan(20));
    controller.setPosition(const Duration(milliseconds: 4900500));
    await tester.pump();
    expect(s.layout, same(layout));
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
      'wrapped text, translation, direction and text scaling retain valid anchors',
      (tester) async {
    final controller = LyricController(
        document: LyricDocument(lines: [
      LyricLine(
          start: const Duration(seconds: 1),
          text: 'A long line of lyrics that wraps onto multiple visual rows',
          translation: '多行翻译与歌词'),
      LyricLine(start: const Duration(seconds: 3), text: 'النهاية'),
    ]));
    addTearDown(controller.dispose);
    await tester.pumpWidget(host(controller, textScale: 1.4));
    await tester.pumpAndSettle();
    var s = session(tester);
    expect(s.activeIndex, -1);
    expect(
        s.layout!.lines.first.text.computeLineMetrics().length, greaterThan(1));
    controller.setPosition(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(s.layout!.offsetFor(0, quiet.activeAnchor, s.size.height),
        closeTo(s.scrollY, .01));
    final oldLayout = s.layout;
    await tester.pumpWidget(host(controller, direction: TextDirection.rtl));
    await tester.pumpAndSettle();
    s = session(tester);
    expect(s.layout, isNot(same(oldLayout)));
    expect(s.layout!.style.direction, TextDirection.rtl);
    controller.setPosition(const Duration(seconds: 4));
    await tester.pumpAndSettle();
    expect(s.layout!.offsetFor(1, quiet.activeAnchor, s.size.height),
        closeTo(s.scrollY, .01));
    controller.setPosition(Duration.zero);
    await tester.pumpAndSettle();
    expect(s.activeIndex, -1);
    expect(s.scrollY, s.scrollController.position.minScrollExtent);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
      'selection builders follow geometry, stale actions expire and empty state works',
      (tester) async {
    final controller = LyricController(document: support.lines());
    addTearDown(controller.dispose);
    LyricSelectionDetails? details;
    final taps = <LyricLineDetails>[];
    final selected = <LyricLineDetails?>[];
    final style = quiet.copyWith(
        emptyBuilder: (_) => const Text('empty'),
        selectionForegroundBuilder: (_, value) {
          details = value;
          return const SizedBox.shrink();
        });
    await tester.pumpWidget(host(controller,
        style: style, onTap: taps.add, onSelection: selected.add));
    await tester.pumpAndSettle();
    await controller.scrollToLine(3, animate: false);
    await tester.pumpAndSettle();
    final stale = details!;
    expect(stale.lineRect, session(tester).lineRect(3));
    final count = selected.length;
    controller.setPosition(const Duration(milliseconds: 400));
    await tester.pump();
    expect(selected.length, count);
    controller.loadDocument(support.lines(count: 2));
    await tester.pumpAndSettle();
    stale.onTap!();
    stale.resumeFollow();
    expect(taps, isEmpty);
    expect(session(tester).following, true);
    controller.clear();
    await tester.pumpAndSettle();
    expect(find.text('empty'), findsOneWidget);
    expect(session(tester).layout, isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
      'cancelling animated scroll resolves pending futures when disposed',
      (tester) async {
    final controller = LyricController(document: support.lines());
    addTearDown(controller.dispose);
    await tester
        .pumpWidget(host(controller, style: const AppleMusicLyricStyle()));
    await tester.pump(const Duration(seconds: 1));
    final moving = controller.scrollToLine(2);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 30));
    await tester.pumpWidget(const SizedBox.shrink());
    await moving;
    expect(controller.hasClients, false);
    expect(tester.binding.transientCallbackCount, 0);
    expect(tester.takeException(), isNull);
  });
}
