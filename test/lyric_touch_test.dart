import 'package:flutter/material.dart';
import 'package:flutter_lyric/flutter_lyric.dart';
import 'package:flutter_lyric/render/lyric_painter.dart';
import 'package:flutter_test/flutter_test.dart';

LyricPainter _painter(WidgetTester tester) => tester
    .widget<CustomPaint>(find.byWidgetPredicate(
      (widget) => widget is CustomPaint && widget.painter is LyricPainter,
    ))
    .painter! as LyricPainter;

Offset _lineCenter(WidgetTester tester, int index) {
  final painter = _painter(tester);
  var y = -painter.scrollY;
  for (var i = 0; i < index; i++) {
    y += painter.layout.getLineHeight(i == painter.playIndex, i) +
        painter.style.lineGap;
  }
  y += painter.layout.getLineHeight(index == painter.playIndex, index) / 2;
  final bounds = tester.getRect(find.byType(LyricView));
  return Offset(bounds.center.dx, bounds.top + y);
}

Future<LyricController> _mountView(WidgetTester tester) async {
  final controller = LyricController()
    ..loadLyric(List.generate(
        12, (i) => '[00:${i.toString().padLeft(2, '0')}.00]Line $i').join('\n'))
    ..setProgress(const Duration(seconds: 2));
  addTearDown(controller.dispose);
  await tester.pumpWidget(MaterialApp(
    home: LyricView(controller: controller, style: LyricStyles.default1),
  ));
  await tester.pumpAndSettle();
  return controller;
}

void main() {
  testWidgets('tapping a line dispatches its start time once', (tester) async {
    final controller = await _mountView(tester);
    final taps = <Duration>[];
    controller.setOnTapLineCallback(taps.add);

    await tester.tapAt(_lineCenter(tester, 3));
    await tester.pump();
    expect(taps, [const Duration(seconds: 3)]);
    expect(controller.isSelectingNotifier.value, isFalse);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
      'a tap does not start selection timers or pin automatic scrolling',
      (tester) async {
    final controller = await _mountView(tester);
    var selectedResumes = 0;
    controller.registerEvent(LyricEvent.resumeSelectedLine, (_) {
      selectedResumes++;
    });

    await tester.tapAt(_lineCenter(tester, 3));
    await tester.pump(const Duration(milliseconds: 400));
    final before = _painter(tester).scrollY;
    controller.setProgress(const Duration(seconds: 3));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    final during = _painter(tester).scrollY;
    expect(during, greaterThan(before));
    await tester.pump(const Duration(milliseconds: 200));
    expect(_painter(tester).scrollY, greaterThan(during));
    expect(selectedResumes, 0);
    expect(controller.isSelectingNotifier.value, isFalse);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('drag selection still resumes automatic scrolling',
      (tester) async {
    final controller = await _mountView(tester);
    await tester.drag(find.byType(LyricView), const Offset(0, -80));
    await tester.pump(const Duration(milliseconds: 500));
    expect(controller.isSelectingNotifier.value, isTrue);
    // Tapping while selection is active must restart its resume timer.
    await tester
        .tapAt(_lineCenter(tester, controller.selectedIndexNotifier.value));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
    expect(controller.isSelectingNotifier.value, isFalse);
    final before = _painter(tester).scrollY;
    controller.setProgress(const Duration(seconds: 4));
    await tester.pumpAndSettle();
    expect(_painter(tester).scrollY, greaterThan(before));
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
