import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_lyric/flutter_lyric.dart';
import 'package:flutter_test/flutter_test.dart';

class _ProgressSource implements LyricProgressSource {
  final StreamController<void> events =
      StreamController<void>.broadcast(sync: true);
  Duration currentPosition = Duration.zero;
  int positionReads = 0;

  @override
  bool isAdvancing = false;

  @override
  Duration get position {
    positionReads++;
    return currentPosition;
  }

  @override
  Stream<void> get changes => events.stream;

  void update(Duration position, {required bool advancing}) {
    currentPosition = position;
    isAdvancing = advancing;
    events.add(null);
  }
}

Widget _view(LyricController controller, {bool enabled = true}) => MaterialApp(
      home: TickerMode(
        enabled: enabled,
        child: LyricView(controller: controller),
      ),
    );

void main() {
  test(
      'replacing or clearing a source detaches it and preserves manual control',
      () {
    final first = _ProgressSource()
      ..currentPosition = const Duration(seconds: 1)
      ..isAdvancing = true;
    final second = _ProgressSource()
      ..currentPosition = const Duration(seconds: 7);
    addTearDown(first.events.close);
    addTearDown(second.events.close);
    final controller = LyricController(progressSource: first);
    addTearDown(controller.dispose);

    expect(controller.progressNotifier.value, const Duration(seconds: 1));
    expect(controller.progressAdvancingListenable.value, isTrue);
    expect(first.events.hasListener, isTrue);

    controller.progressSource = second;
    expect(first.events.hasListener, isFalse);
    expect(second.events.hasListener, isTrue);
    expect(controller.progressNotifier.value, const Duration(seconds: 7));
    expect(controller.progressAdvancingListenable.value, isFalse);

    first.update(const Duration(seconds: 99), advancing: true);
    expect(controller.progressNotifier.value, const Duration(seconds: 7));
    second.update(const Duration(seconds: 8), advancing: false);
    expect(controller.progressNotifier.value, const Duration(seconds: 8));

    controller.progressSource = null;
    expect(second.events.hasListener, isFalse);
    expect(controller.progressNotifier.value, const Duration(seconds: 8));
    controller.setProgress(const Duration(seconds: 3));
    second.update(const Duration(seconds: 100), advancing: true);
    expect(controller.progressNotifier.value, const Duration(seconds: 3));
    expect(controller.progressAdvancingListenable.value, isFalse);
  });

  test('disposing one controller keeps a shared source usable by another', () {
    final source = _ProgressSource();
    addTearDown(source.events.close);
    final first = LyricController(progressSource: source);
    final second = LyricController(progressSource: source);

    first.dispose();
    expect(source.events.hasListener, isTrue);
    source.update(const Duration(seconds: 4), advancing: false);
    expect(second.progressNotifier.value, const Duration(seconds: 4));
    second.dispose();
    expect(source.events.hasListener, isFalse);
    expect(source.events.isClosed, isFalse);
  });

  testWidgets(
      'samples every frame, stops while paused, and handles paused seeks',
      (tester) async {
    final source = _ProgressSource()..isAdvancing = true;
    addTearDown(source.events.close);
    final controller = LyricController(progressSource: source);
    addTearDown(controller.dispose);
    await tester.pumpWidget(_view(controller));

    // Sampling follows frame delivery, including intervals shorter than 16 ms.
    for (final interval in [16, 8, 11]) {
      source.currentPosition += Duration(milliseconds: interval);
      final reads = source.positionReads;
      await tester.pump(Duration(milliseconds: interval));
      expect(source.positionReads, reads + 1);
      expect(controller.progressNotifier.value, source.currentPosition);
    }

    source.update(const Duration(seconds: 1), advancing: false);
    final reads = source.positionReads;
    await tester.pump(const Duration(seconds: 1));
    expect(source.positionReads, reads);
    expect(tester.binding.transientCallbackCount, 0);
    expect(controller.progressNotifier.value, const Duration(seconds: 1));

    source.update(const Duration(seconds: 10), advancing: false);
    expect(controller.progressNotifier.value, const Duration(seconds: 10));
    expect(tester.binding.transientCallbackCount, 0);

    source.update(const Duration(seconds: 10), advancing: true);
    source.currentPosition = const Duration(milliseconds: 10008);
    await tester.pump(const Duration(milliseconds: 8));
    expect(controller.progressNotifier.value, source.currentPosition);

    // Buffering and completion use the same non-advancing contract as pause.
    source.update(const Duration(seconds: 11), advancing: false);
    await tester.pump(const Duration(milliseconds: 8));
    expect(tester.binding.transientCallbackCount, 0);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('replacement updates the active ticker and clearing stops it',
      (tester) async {
    final first = _ProgressSource();
    final second = _ProgressSource()
      ..currentPosition = const Duration(seconds: 20)
      ..isAdvancing = true;
    addTearDown(first.events.close);
    addTearDown(second.events.close);
    final controller = LyricController(progressSource: first);
    addTearDown(controller.dispose);
    await tester.pumpWidget(_view(controller));

    controller.progressSource = second;
    expect(controller.progressNotifier.value, const Duration(seconds: 20));
    second.currentPosition = const Duration(milliseconds: 20008);
    await tester.pump(const Duration(milliseconds: 8));
    expect(controller.progressNotifier.value, second.currentPosition);

    // Replacing a playing source with another playing source must read the new
    // getter even though the advancing state itself does not change.
    first.update(const Duration(seconds: 30), advancing: true);
    controller.progressSource = first;
    first.currentPosition = const Duration(milliseconds: 30008);
    await tester.pump(const Duration(milliseconds: 8));
    expect(controller.progressNotifier.value, first.currentPosition);

    controller.progressSource = null;
    controller.setProgress(const Duration(seconds: 5));
    first.update(const Duration(seconds: 40), advancing: true);
    await tester.pump(const Duration(milliseconds: 8));
    expect(controller.progressNotifier.value, const Duration(seconds: 5));
    expect(tester.binding.transientCallbackCount, 0);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
      'TickerMode and unmounting stop sampling without stopping the source',
      (tester) async {
    final source = _ProgressSource()..isAdvancing = true;
    addTearDown(source.events.close);
    final controller = LyricController(progressSource: source);
    addTearDown(controller.dispose);
    await tester.pumpWidget(_view(controller));
    await tester.pumpWidget(_view(controller, enabled: false));
    final reads = source.positionReads;
    source.currentPosition = const Duration(seconds: 10);
    await tester.pump(const Duration(seconds: 10));
    expect(source.positionReads, reads);

    await tester.pumpWidget(_view(controller));
    await tester.pump(const Duration(milliseconds: 8));
    expect(controller.progressNotifier.value, const Duration(seconds: 10));
    await tester.pumpWidget(const SizedBox.shrink());
    final readsAfterUnmount = source.positionReads;
    await tester.pump(const Duration(seconds: 1));
    expect(source.positionReads, readsAfterUnmount);
    expect(source.events.hasListener, isTrue);
    expect(tester.binding.transientCallbackCount, 0);
  });
}
