import 'package:flutter/widgets.dart';
import 'package:flutter_lyric/flutter_lyric.dart';
import 'package:flutter_test/flutter_test.dart';
import 'test_support.dart';

void main() {
  test('LRC parsing preserves source order for duplicate timestamps', () {
    final document = LyricDocument.parse(
        List.generate(80, (i) => '[00:01.00]$i').join('\n'));
    expect(document.lines.map((line) => line.text),
        List.generate(80, (i) => '$i'));
  });
  testWidgets('commands after load wait for the new geometry', (tester) async {
    final controller = LyricController(document: lines(count: 2));
    addTearDown(controller.dispose);
    await tester.pumpWidget(host(controller, preset: quietPreset));
    await tester.pumpAndSettle();
    controller.loadDocument(lines(count: 40));
    final scrolling = controller.scrollToLine(30, animate: false);
    await tester.pump();
    await scrolling;
    expect(session(tester).selectedIndex, 30);
    expect(session(tester).lineRect(30).center.dy, closeTo(120, .001));
    await tester.pumpWidget(const SizedBox.shrink());
  });
  testWidgets('direction, system scale and font notifications update metrics',
      (tester) async {
    final controller = LyricController(document: lines());
    addTearDown(controller.dispose);
    Future<void> show(TextDirection direction, double scale) async {
      await tester.pumpWidget(MediaQuery(
          // ignore: deprecated_member_use
          data: MediaQueryData(textScaleFactor: scale),
          child: host(controller,
              direction: direction,
              preset: quietPreset.copyWith(
                  contentAlignment: LyricContentAlignment.start,
                  padding:
                      const EdgeInsetsDirectional.only(start: 30, end: 10)))));
      await tester.pumpAndSettle();
    }

    await show(TextDirection.ltr, 1);
    final first = session(tester).layout!.metrics;
    final height = first.first.activeHeight;
    await show(TextDirection.rtl, 2);
    final state = session(tester);
    expect(state.layout!.style.padding.left, 10);
    expect(state.layout!.style.padding.right, 30);
    expect(state.layout!.metrics, isNot(same(first)));
    expect(state.layout!.metrics.first.activeHeight, greaterThan(height));
    expect(state.layout!.metrics.first.textPainter.textDirection,
        TextDirection.rtl);
    expect(state.painter!.contentOffsetX(100, 360), 260);
    final beforeFonts = state.layout!.metrics;
    state.fontsChanged();
    await tester.pumpAndSettle();
    expect(state.layout!.metrics, isNot(same(beforeFonts)));
    await tester.pumpWidget(const SizedBox.shrink());
  });
  test('documents copy inputs, sort stably, and expose immutable collections',
      () {
    final first = LyricLine(start: const Duration(seconds: 1), text: 'first');
    final last = LyricLine(start: const Duration(seconds: 1), text: 'last');
    final input = [first, LyricLine(start: Duration.zero, text: 'zero'), last];
    final tags = {'offset': '200'};
    final document = LyricDocument(lines: input, tags: tags);
    input.clear();
    tags.clear();
    expect(document.lines.map((line) => line.text), ['zero', 'first', 'last']);
    expect(document.offset, const Duration(milliseconds: 200));
    expect(() => document.lines.clear(), throwsUnsupportedError);
    expect(() => document.tags.clear(), throwsUnsupportedError);
  });
  test('controller publishes atomic offsets and deterministic active indices',
      () {
    final document =
        LyricDocument(offset: const Duration(milliseconds: 200), lines: [
      LyricLine(start: const Duration(seconds: 1), text: 'first'),
      LyricLine(start: const Duration(seconds: 1), text: 'duplicate'),
      LyricLine(start: const Duration(seconds: 2), text: 'last')
    ]);
    final controller = LyricController(
        document: document, timeOffset: const Duration(milliseconds: 100));
    addTearDown(controller.dispose);
    final indices = <int?>[];
    controller.activeLineIndexListenable.addListener(() {
      indices.add(controller.activeLineIndexListenable.value);
      expect(controller.effectivePosition,
          controller.position + document.offset + controller.timeOffset);
      expect(controller.value.activeLineIndex,
          controller.activeLineIndexListenable.value);
    });
    expect(controller.activeLineIndex, isNull);
    controller.setPosition(const Duration(milliseconds: 700));
    expect(controller.activeLine!.text, 'duplicate');
    controller.setPosition(const Duration(milliseconds: 800));
    expect(indices, [1]);
    controller.setPosition(const Duration(seconds: 20));
    expect(controller.activeLineIndex, 2);
    controller.clear();
    expect(controller.document, isNull);
    expect(controller.position, const Duration(seconds: 20));
    expect(controller.timeOffset, const Duration(milliseconds: 100));
    expect(indices, [1, 2, null]);
  });
  test(
      'preset copies clear nullable values explicitly and compare structurally',
      () {
    Widget builder(BuildContext context) => const SizedBox.shrink();
    final preset = LyricPresets.moss.copyWith(emptyBuilder: builder);
    expect(preset.copyWith(), preset);
    expect(preset.copyWith().hashCode, preset.hashCode);
    expect(preset.copyWith(emptyBuilder: null).emptyBuilder, same(builder));
    expect(preset.copyWith(clearEmptyBuilder: true).emptyBuilder, isNull);
    expect(preset.copyWith(clearResumeDelay: true).resumeDelay, isNull);
    expect(
        () => preset.copyWith(emptyBuilder: builder, clearEmptyBuilder: true),
        throwsArgumentError);
    expect(
        () =>
            preset.copyWith(resumeDelay: Duration.zero, clearResumeDelay: true),
        throwsArgumentError);
    final durations = <double, Duration>{
      100: const Duration(seconds: 1),
      20: const Duration(milliseconds: 100)
    };
    final animation = LyricScrollAnimation.byDistance(durations: durations);
    durations.clear();
    expect(animation.resolve(10).duration, const Duration(milliseconds: 240));
    expect(animation.resolve(20).duration, const Duration(milliseconds: 100));
    expect(animation.resolve(150).duration, const Duration(seconds: 1));
    expect(() => animation.durations.clear(), throwsUnsupportedError);
    expect(const LyricEdgeFade.fraction(top: .8, bottom: .8).resolve(200),
        [.5, .5]);
  });
  testWidgets('two views share playback and keep independent selection',
      (tester) async {
    final controller = LyricController(document: lines());
    addTearDown(controller.dispose);
    await tester.pumpWidget(Directionality(
        textDirection: TextDirection.ltr,
        child: Row(children: [
          Expanded(
              child: LyricView(
                  controller: controller, viewId: 'a', preset: quietPreset)),
          Expanded(
              child: LyricView(
                  controller: controller, viewId: 'b', preset: quietPreset)),
        ])));
    await tester.pumpAndSettle();
    expect(controller.attachedViewIds, ['a', 'b']);
    await controller.scrollToLine(10, viewId: 'a', animate: false);
    expect(session(tester).selectedIndex, 10);
    expect(session(tester, at: 1).following, isTrue);
    controller.setPosition(const Duration(seconds: 3));
    await tester.pumpAndSettle();
    expect(session(tester).selectedIndex, 10);
    expect(session(tester).activeIndex, 3);
    expect(session(tester, at: 1).activeIndex, 3);
    expect(() => controller.resumeFollow(viewId: 'missing'), throwsStateError);
    await controller.resumeFollow(animate: false);
    expect(session(tester).following, isTrue);
    expect(session(tester, at: 1).following, isTrue);
    await tester.pumpWidget(const SizedBox.shrink());
    expect(controller.hasClients, isFalse);
    await controller
        .scrollToLine(999); // broadcast to no attachments is a no-op.
  });
  testWidgets('scope inheritance is whole-preset and explicit preset wins',
      (tester) async {
    final controller = LyricController(document: lines());
    addTearDown(controller.dispose);
    Future<void> show(LyricPreset? explicit) async {
      await tester.pumpWidget(LyricPresetScope(
          preset: LyricPresets.cinema,
          child: host(controller, preset: explicit)));
      await tester.pumpAndSettle();
    }

    await show(null);
    expect(session(tester).preset, LyricPresets.cinema);
    expect(session(tester).layout!.metrics, hasLength(1));
    await show(quietPreset);
    expect(session(tester).preset, quietPreset);
    expect(session(tester).layout!.metrics, hasLength(30));
    await tester.pumpWidget(const SizedBox.shrink());
  });
  testWidgets('preset mode switches preserve playback and clear browsing',
      (tester) async {
    final controller = LyricController(
        document: lines(count: 1000),
        initialPosition: const Duration(seconds: 500));
    addTearDown(controller.dispose);
    final changes = <int?>[];
    Future<void> show(LyricPreset preset) async {
      await tester.pumpWidget(host(controller,
          preset: preset,
          onSelectionChanged: (line) => changes.add(line?.index)));
      await tester.pumpAndSettle();
    }

    await show(quietPreset);
    await controller.scrollToLine(800, animate: false);
    await show(LyricPresets.cinema);
    expect(changes.last, isNull);
    expect(controller.position, const Duration(seconds: 500));
    expect(session(tester).layout!.metrics, hasLength(1));
    expect(session(tester).layout!.metrics.single.line,
        same(controller.activeLine));
    controller.setPosition(const Duration(seconds: 501));
    await tester.pumpAndSettle();
    expect(session(tester).layout!.metrics, hasLength(1));
    expect(session(tester).layout!.firstIndex, 501);
    await show(quietPreset);
    expect(session(tester).following, isTrue);
    expect(session(tester).layout!.metrics, hasLength(1000));
    await tester.pumpWidget(const SizedBox.shrink());
  });
  testWidgets(
      'builders get local geometry and old actions expire on replacement',
      (tester) async {
    final controller = LyricController(document: lines());
    final replacement = LyricController(document: lines());
    addTearDown(controller.dispose);
    addTearDown(replacement.dispose);
    LyricSelectionDetails? latest;
    final taps = <LyricLineDetails>[];
    final preset =
        quietPreset.copyWith(selectionForegroundBuilder: (context, details) {
      latest = details;
      return Stack(children: [
        Positioned(
            top: details.lineRect.top,
            child: GestureDetector(
                onTap: details.onTap, child: const Text('Seek')))
      ]);
    });
    await tester
        .pumpWidget(host(controller, preset: preset, onLineTap: taps.add));
    await tester.pumpAndSettle();
    await controller.scrollToLine(10, animate: false);
    await tester.pumpAndSettle();
    final old = latest!;
    expect(old.viewportSize, const Size(400, 240));
    expect(old.lineRect.center.dy, closeTo(120, .001));
    expect(old.contentRect.left, 20);
    expect(old.line.index, 10);
    expect(old.isSnapped, isTrue);
    controller.loadDocument(lines());
    old.onTap!();
    old.resumeFollow();
    expect(taps, isEmpty);
    await tester.pumpAndSettle();
    expect(find.text('Seek'), findsNothing);
    await controller.scrollToLine(2, animate: false);
    await tester.pumpAndSettle();
    final oldView = latest!;
    await tester
        .pumpWidget(host(replacement, preset: preset, onLineTap: taps.add));
    await tester.pumpAndSettle();
    oldView.onTap!();
    oldView.resumeFollow();
    expect(taps, isEmpty);
    expect(controller.hasClients, isFalse);
    expect(replacement.hasClients, isTrue);
    await tester.pumpWidget(const SizedBox.shrink());
  });
  testWidgets(
      'empty builder handles missing lyrics and active-only before first line',
      (tester) async {
    final controller = LyricController();
    addTearDown(controller.dispose);
    final preset =
        LyricPresets.cinema.copyWith(emptyBuilder: (_) => const Text('Empty'));
    await tester.pumpWidget(host(controller, preset: preset));
    await tester.pumpAndSettle();
    expect(find.text('Empty'), findsOneWidget);
    controller.load('[00:01.00]First');
    await tester.pumpAndSettle();
    expect(find.text('Empty'), findsOneWidget);
    expect(session(tester).layout, isNull);
    controller.setPosition(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(find.text('Empty'), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
  });
  testWidgets(
      'first and last lines align without large padding, including resize',
      (tester) async {
    final controller = LyricController(document: lines());
    addTearDown(controller.dispose);
    await tester.pumpWidget(host(controller, preset: quietPreset));
    await tester.pumpAndSettle();
    expect(session(tester).lineRect(0).center.dy, closeTo(120, .001));
    controller.setPosition(const Duration(seconds: 29));
    await tester.pumpAndSettle();
    expect(session(tester).lineRect(29).center.dy, closeTo(120, .001));
    await tester.pumpWidget(
        host(controller, preset: quietPreset, size: const Size(300, 400)));
    await tester.pumpAndSettle();
    expect(session(tester).lineRect(29).center.dy, closeTo(200, .001));
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
