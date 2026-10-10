import 'package:flutter/material.dart';
import 'package:flutter_lyric/widgets/mixins/lyric_layout_mixin.dart';

/// 负责当前播放行逐字高亮宽度的计算与通知 Mixin
mixin LyricLineHightlightMixin<T extends StatefulWidget>
    on State<T>, LyricLayoutMixin<T> {
  final ValueNotifier<double> activeHighlightWidthNotifier = ValueNotifier(0.0);

  @override
  void initState() {
    controller.activeIndexNotifiter.addListener(_onActiveIndexChange);
    controller.progressNotifier.addListener(updateHighlightWidth);

    super.initState();
  }

  void _onActiveIndexChange() {
    if (!mounted) {
      return;
    }
    updateHighlightWidth();
  }

  @override
  void dispose() {
    controller.activeIndexNotifiter.removeListener(_onActiveIndexChange);
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
      _setHighlightWidth(0.0);
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
    _setHighlightWidth(newWidth);
  }

  void _setHighlightWidth(double newWidth) {
    if (!mounted) {
      return;
    }

    if (activeHighlightWidthNotifier.value == newWidth) {
      return;
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
