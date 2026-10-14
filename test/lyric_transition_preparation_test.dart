import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_lyric/flutter_lyric.dart';
import 'package:flutter_lyric/src/rendering/lyric_layout.dart';
import 'package:flutter_lyric/src/rendering/resolved_preset.dart';
import 'test_support.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('fixed line switch leaves inactive candidate paragraphs deferred',
      (tester) async {
    final controller = LyricController(
        document: lines(count: 100),
        initialPosition: const Duration(milliseconds: 20500));
    addTearDown(controller.dispose);
    await tester.pumpWidget(host(controller,
        preset: LyricPresets.appleMusic, size: const Size(400, 360)));
    await tester.pump(const Duration(seconds: 1));
    final state = session(tester);
    final layout = state.layout!;
    final counts = {
      for (final index in state.visibleIndices)
        if (index != state.activeIndex && index != state.activeIndex + 1)
          index: layout.metric(index).debugPainterCount,
    };
    expect(counts, isNotEmpty);
    expect(counts.values, everyElement(2));

    // Check the synchronous transition preparation, before painting the new
    // active line. Rows used only for culling need no active paragraph.
    controller.setPosition(const Duration(milliseconds: 21500));
    expect(state.layout, same(layout));
    for (final entry in counts.entries) {
      expect(layout.metric(entry.key).debugPainterCount, entry.value,
          reason: 'inactive candidate ${entry.key}');
      expect(layout.metric(entry.key).debugCharactersComputed, isFalse);
    }
    await tester.pump(const Duration(milliseconds: 100));
    expect(state.layout, same(layout));
    expect(layout.metrics[80].debugPainterCount, 2);
    expect(layout.metrics[80].debugCharactersComputed, isFalse);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  for (final direction in TextDirection.values) {
    for (final simulated in [false, true]) {
      test(
          'exact grapheme timing reuses wrapped clips ($direction, $simulated)',
          () {
        const content = 'AB אב e\u0301 CD\nאב AB CD e\u0301';
        final clusters = content.characters.toList();
        final layout = LyricLayout.compute(
            LyricDocument(lines: [
              LyricLine(
                  start: Duration.zero,
                  end: const Duration(seconds: 4),
                  text: content,
                  words: simulated
                      ? null
                      : [
                          for (var i = 0; i < clusters.length; i++)
                            LyricWord(
                                text: clusters[i],
                                start: Duration(milliseconds: i * 100),
                                end: Duration(milliseconds: (i + 1) * 100)),
                        ]),
              LyricLine(start: const Duration(seconds: 4), text: 'unvisited'),
            ]),
            ResolvedPreset(
                LyricPresets.appleMusic.copyWith(padding: EdgeInsets.zero),
                direction: direction),
            const Size(120, 360));
        addTearDown(layout.dispose);
        final line = layout.wordLine(0, true);
        expect(line.text.computeLineMetrics().length, greaterThan(2));
        expect(line.debugCharactersComputed, isFalse);
        final segments = line.segments;
        expect(line.debugCharactersComputed, isFalse);
        expect(segments, hasLength(clusters.length));
        final characters = line.characters;
        expect(characters, hasLength(clusters.length));
        for (var i = 0; i < characters.length; i++) {
          final character = characters[i];
          expect(character.segment, same(segments[i]));
          expect(character.clips, same(segments[i].clips));
          final boxes = line.text.getBoxesForSelection(TextSelection(
              baseOffset: character.startOffset,
              extentOffset: character.endOffset));
          expect(character.clips, hasLength(boxes.length));
          for (var j = 0; j < boxes.length; j++) {
            final clip = character.clips[j];
            final box = boxes[j];
            // Legacy native paragraph metrics lose sub-micro-pixel precision
            // when crossing the float/double boundary.
            const epsilon = 1e-6;
            expect(clip.left, lessThanOrEqualTo(box.left + epsilon));
            expect(clip.right, greaterThanOrEqualTo(box.right - epsilon));
            expect(clip.top, lessThanOrEqualTo(box.top + epsilon));
            expect(clip.bottom, greaterThanOrEqualTo(box.bottom - epsilon));
          }
        }
        expect(layout.metrics.last.debugWordLineComputed, isFalse);
      });
    }
  }

  test('a word spanning wrapped rows keeps separate character slices', () {
    const content = 'ABCD EFGH IJKL';
    final layout = LyricLayout.compute(
        LyricDocument(lines: [
          LyricLine(start: Duration.zero, text: content, words: const [
            LyricWord(
                text: content, start: Duration.zero, end: Duration(seconds: 4)),
          ]),
        ]),
        ResolvedPreset(
            LyricPresets.appleMusic.copyWith(padding: EdgeInsets.zero)),
        const Size(120, 360));
    addTearDown(layout.dispose);
    final line = layout.wordLine(0, true);
    final segment = line.segments.single;
    expect(segment.boxes.length, greaterThan(1));
    for (final character in line.characters) {
      expect(character.segment, same(segment));
      expect(character.clips, isNot(same(segment.clips)));
      expect(character.clips.length, lessThan(segment.clips.length));
    }
  });
}
