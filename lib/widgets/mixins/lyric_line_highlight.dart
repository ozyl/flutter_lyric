import 'package:flutter/material.dart';
import 'package:flutter_lyric/widgets/mixins/lyric_layout_mixin.dart';

// 动画时长：例如 50 毫秒
const Duration _kHighlightTransitionDuration = Duration(milliseconds: 200);

// 必须混入 TickerProviderStateMixin 才能使用 AnimationController
mixin LyricLineHightlightMixin<T extends StatefulWidget>
    on State<T>, LyricLayoutMixin<T>, TickerProviderStateMixin<T> {
  late final AnimationController _animationController;
  Animation<double>? _widthAnimation;

  var activeHighlightWidthNotifier = ValueNotifier(0.0);

  @override
  void initState() {
    _animationController = AnimationController(
      vsync: this,
      duration: _kHighlightTransitionDuration,
    );

    // 监听动画值的变化，并将最新值通知给 ValueNotifier
    _animationController.addListener(() {
      if (_widthAnimation != null) {
        activeHighlightWidthNotifier.value = _widthAnimation!.value;
      }
    });

    controller.activeIndexNotifiter.addListener(_onActiveIndexChange);
    controller.progressNotifier.addListener(updateHighlightWidth);

    super.initState();
  }

  _onActiveIndexChange() {
    updateHighlightWidth();
  }

  @override
  void dispose() {
    controller.activeIndexNotifiter.removeListener(_onActiveIndexChange);
    controller.progressNotifier.removeListener(updateHighlightWidth);
    _animationController.dispose();
    activeHighlightWidthNotifier.dispose();
    super.dispose();
  }

  void updateHighlightWidth() {
    final index = controller.activeIndexNotifiter.value;
    final metrics = layout?.metrics ?? [];

    if (index >= metrics.length || index < 0) {
      _animateWidth(0.0);
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
    _animateWidth(newWidth);
  }

  void _animateWidth(double newWidth) {
    final currentWidth = activeHighlightWidthNotifier.value;

    // 1. 如果新宽度与当前宽度相同，不做任何事。
    if (currentWidth == newWidth) return;
    if (newWidth < currentWidth) {
      _animationController.stop();
      activeHighlightWidthNotifier.value = newWidth;
      return;
    }
    // 线性动画，无论增减都线性过渡
    _widthAnimation = Tween<double>(
      begin: currentWidth,
      end: newWidth,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.linear,
    ));

    _animationController
      ..reset()
      ..forward();
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
