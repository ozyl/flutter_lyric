import 'package:flutter/material.dart';
import 'package:flutter_lyric/widgets/mixins/lyric_layout_mixin.dart';

mixin LyricLineHightlightMixin<T extends StatefulWidget>
    on State<T>, LyricLayoutMixin<T> {
  final ValueNotifier<double> activeHighlightWidthNotifier = ValueNotifier(0.0);

  @override
  void initState() {
    controller.activeIndexNotifiter.addListener(updateHighlightWidth);
    controller.progressNotifier.addListener(updateHighlightWidth);

    super.initState();
  }

  @override
  void dispose() {
    controller.activeIndexNotifiter.removeListener(updateHighlightWidth);
    controller.progressNotifier.removeListener(updateHighlightWidth);
    activeHighlightWidthNotifier.dispose();
    super.dispose();
  }

  void updateHighlightWidth() {
    if (!mounted) {
      return;
    }
    final index = controller.activeIndexNotifiter.value;
    final metrics = layout?.metrics ?? [];

    if (index >= metrics.length || index < 0) {
      activeHighlightWidthNotifier.value = 0.0;
      return;
    }

    final line = metrics[index];
    var newWidth = 0.0;
    final currentProgress = controller.progressNotifier.value +
        Duration(milliseconds: controller.lyricOffset);

    line.words?.forEach((wordMetric) {
      if (currentProgress >= wordMetric.word.start) {
        newWidth += wordMetric.highlightWidth;
        final endTime = (wordMetric.word.end ?? Duration.zero);
        if (currentProgress < endTime) {
          final wordDuration = (endTime - wordMetric.word.start).inMilliseconds;
          final elapsed =
              (currentProgress - wordMetric.word.start).inMilliseconds;

          if (wordDuration > 0) {
            newWidth -=
                wordMetric.highlightWidth * (1 - elapsed / wordDuration);
          }
        }
      }
    });
    final words = line.words;
    if (words != null && words.isNotEmpty) {
      final lastWord = words.last.word;
      final lastEnd = lastWord.end ?? Duration.zero;
      if (lastEnd > lastWord.start && currentProgress >= lastEnd) {
        newWidth += style.activeHighlightExtraFadeWidth;
      }
    }
    activeHighlightWidthNotifier.value = newWidth;
  }

  Widget buildActiveHighlightWidth(Widget Function(double value) builder) {
    return ValueListenableBuilder<double>(
      valueListenable: activeHighlightWidthNotifier,
      builder: (context, value, child) {
        return builder(value);
      },
    );
  }
}
