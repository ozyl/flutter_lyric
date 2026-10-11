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

    final words = line.words ?? [];
    final extraFadeWidth = style.activeHighlightExtraFadeWidth;
    for (var i = 0; i < words.length; i++) {
      final wordMetric = words[i];
      if (currentProgress >= wordMetric.word.start) {
        final endTime = (wordMetric.word.end ?? Duration.zero);
        var highlightWidth = wordMetric.highlightWidth;
        if (i == words.length - 1 &&
            endTime > wordMetric.word.start &&
            extraFadeWidth > 0) {
          // Move the fade past the line's end during the last word, so the
          // tail reaches full opacity continuously instead of snapping at end.
          highlightWidth += extraFadeWidth;
        }
        newWidth += highlightWidth;
        if (currentProgress < endTime) {
          final wordDuration = (endTime - wordMetric.word.start).inMilliseconds;
          final elapsed =
              (currentProgress - wordMetric.word.start).inMilliseconds;

          if (wordDuration > 0) {
            newWidth -= highlightWidth * (1 - elapsed / wordDuration);
          }
        }
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
