import 'package:flutter/widgets.dart';
import 'package:flutter_lyric/flutter_lyric.dart';
import 'package:flutter_test/flutter_test.dart';
import 'test_support.dart';

void main() {
  testWidgets('onDragPause snaps without cancelling the held gesture',
      (tester) async {
    final controller = LyricController(document: lines());
    addTearDown(controller.dispose);
    await tester.pumpWidget(host(controller,
        preset: quietPreset.copyWith(
            selectionSnapMode: LyricSelectionSnapMode.onDragPause,
            selectionSnapDelay: const Duration(milliseconds: 100))));
    await tester.pumpAndSettle();
    final gesture =
        await tester.startGesture(tester.getCenter(find.byType(LyricView)));
    await gesture.moveBy(const Offset(0, -73));
    await tester.pump(const Duration(milliseconds: 150));
    final state = session(tester);
    expect(state.selectionDetails!.isSnapped, isTrue);
    expect(state.dragging, isTrue);
    final snapped = state.scrollY;
    await gesture.moveBy(const Offset(0, -60));
    await tester.pump(const Duration(milliseconds: 16));
    expect(state.scrollY, greaterThan(snapped));
    await gesture.up();
    await tester.pumpWidget(const SizedBox.shrink());
  });
  testWidgets('tap uses player timeline and does not change playback',
      (tester) async {
    final controller = LyricController(
        document: lines(offset: const Duration(milliseconds: 200)),
        initialPosition: const Duration(seconds: 2),
        timeOffset: const Duration(milliseconds: 100));
    addTearDown(controller.dispose);
    final taps = <LyricLineDetails>[];
    await tester
        .pumpWidget(host(controller, preset: quietPreset, onLineTap: taps.add));
    await tester.pumpAndSettle();
    final state = session(tester);
    await tester.tapAt(
        tester.getTopLeft(find.byType(LyricView)) + state.lineRect(3).center);
    expect(taps.single.index, 3);
    expect(taps.single.seekPosition, const Duration(milliseconds: 2700));
    expect(controller.position, const Duration(seconds: 2));
    expect(state.following, isTrue);
    await tester.pumpWidget(const SizedBox.shrink());
  });
  testWidgets('drag browses, emits semantic selections, then resumes',
      (tester) async {
    final controller = LyricController(
        document: lines(), initialPosition: const Duration(seconds: 2));
    addTearDown(controller.dispose);
    final selections = <int?>[];
    final follows = <bool>[];
    await tester.pumpWidget(host(controller,
        preset: quietPreset.copyWith(resumeDelay: const Duration(seconds: 1)),
        onSelectionChanged: (line) => selections.add(line?.index),
        onFollowChanged: follows.add));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(LyricView), const Offset(0, -80));
    await tester.pump(const Duration(milliseconds: 100));
    expect(session(tester).following, isFalse);
    expect(selections.where((i) => i != null), isNotEmpty);
    for (var i = 1; i < selections.length; i++) {
      expect(selections[i], isNot(selections[i - 1]));
    }
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    expect(follows, [false, true]);
    expect(selections.last, isNull);
    expect(session(tester).following, isTrue);
    await tester.pumpWidget(const SizedBox.shrink());
  });
  testWidgets('resume earlier than snap cancels pending snap', (tester) async {
    final controller = LyricController(document: lines());
    addTearDown(controller.dispose);
    await tester.pumpWidget(host(controller,
        preset: quietPreset.copyWith(
            selectionSnapMode: LyricSelectionSnapMode.afterScroll,
            selectionSnapDelay: const Duration(seconds: 2),
            resumeDelay: const Duration(milliseconds: 100))));
    await tester.pumpAndSettle();
    await controller.scrollToLine(10, animate: false);
    await tester.pump(const Duration(milliseconds: 110));
    expect(session(tester).following, isTrue);
    final offset = session(tester).scrollY;
    await tester.pump(const Duration(seconds: 3));
    expect(session(tester).scrollY, offset);
    await tester.pumpWidget(const SizedBox.shrink());
  });
  testWidgets('snap and no-auto-resume are independent', (tester) async {
    final controller = LyricController(document: lines());
    addTearDown(controller.dispose);
    await tester.pumpWidget(host(controller,
        preset: quietPreset.copyWith(
            selectionSnapMode: LyricSelectionSnapMode.afterScroll,
            selectionSnapDelay: const Duration(milliseconds: 100))));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(LyricView), const Offset(0, -73));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 150));
    expect(session(tester).selectionDetails!.isSnapped, isTrue);
    await tester.pump(const Duration(seconds: 10));
    expect(session(tester).following, isFalse);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
