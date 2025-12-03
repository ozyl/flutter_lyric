import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_lyric/core/lyric_controller.dart';
import 'package:flutter_lyric/core/lyric_style.dart';
import 'package:flutter_lyric/widgets/mixins/lyric_scroll_mixin.dart';

/// 负责触摸交互的 Mixin（重构版）
mixin LyricTouchMixin<T extends StatefulWidget>
    on State<T>, LyricScrollMixin<T> {
  final Debouncer _selecteResumeDebouncer = Debouncer();
  final Debouncer _activeResumeDebouncer = Debouncer();
  // 拖动偏移
  @override
  double? dragScrollY;
  Map<int, Rect>? showLineRects;

  // fling 动画控制器
  late final AnimationController _flingController;

  @override
  void initState() {
    super.initState();
    controller.registerEvent(LyricEvent.stopSelection, _stopSelection);
    _flingController = AnimationController.unbounded(vsync: this)
      ..addListener(_flingListener)
      ..addStatusListener(_flingStatusListener);
  }

  void _flingListener() {
    final value = _flingController.value;
    setDragTranslationY(value);
  }

  void _stopSelection(_) {
    stopFlingController();
    _activeResumeDebouncer.dispose();
    _selecteResumeDebouncer.dispose();
    _isDragging = false;
    controller.isSelectingNotifier.value = false;
    dragScrollY = null;
    updateScrollY();
  }

  void _flingStatusListener(AnimationStatus status) {
    if (status == AnimationStatus.completed) {
      _scheduleResumeActiveLine();
    }
  }

  void stopFlingController() {
    if (_flingController.isAnimating) {
      _flingController.stop();
    }
  }

  /// 设置拖动偏移，同时限制在范围内
  void setDragTranslationY(double value, {bool animate = false}) {
    final l = layout;
    if (l == null) return;
    final anchorPosition = layout!.selectionAnchorPosition;
    final anchorOffset = layout!.anchorOffsetY(
        0,
        0 == controller.activeIndexNotifiter.value,
        null,
        style.selectionAlignment);
    double minValue = anchorPosition < style.contentPadding.top ||
            contentHeight < anchorPosition
        ? -anchorPosition + anchorOffset
        : -style.contentPadding.top;
    final maxValue = contentHeight - style.contentPadding.top - anchorPosition;
    final newValue = value.clamp(minValue, maxValue);

    if (newValue != dragScrollY) {
      dragScrollY = newValue;
      updateScrollY(animate: animate);
    }

    // 如果越界则停止 fling
    if (value != newValue && _flingController.isAnimating) {
      stopFlingController();
      _scheduleResumeActiveLine();
    }
  }

  /// 延迟恢复播放行位置（防抖）
  void _scheduleResumeActiveLine() {
    scheduleResumeSelectedLine();
    if (_isDragging) return;
    _activeResumeDebouncer(style.activeAutoResumeDuration, () {
      if (_isDragging) return;
      controller.isSelectingNotifier.value = false;
      dragScrollY = null;
      updateScrollY();
      controller.notifyEvent(LyricEvent.resumeActiveLine);
    });
  }

  var _isDragging = false;

  scheduleResumeSelectedLine() {
    // 如果播放和选择恢复时间相同，则不进行恢复
    if (style.selectionAutoResumeMode == SelectionAutoResumeMode.neverResume ||
        style.selectionAutoResumeDuration >= style.activeAutoResumeDuration) {
      return;
    }
    _selecteResumeDebouncer(style.selectionAutoResumeDuration, () {
      setDragTranslationY(
        layout?.lineOffsetY(
                controller.selectedIndexNotifier.value,
                controller.activeIndexNotifiter.value,
                layout?.selectionAnchorPosition ?? 0,
                style.selectionAlignment) ??
            0,
        animate: true,
      );
      controller.notifyEvent(LyricEvent.resumeSelectedLine);
    });
  }

  /// 包装触摸组件
  Widget wrapTouchWidget(BuildContext context, Widget child) {
    if (style.disableTouchEvent || (layout?.metrics.isEmpty ?? true)) {
      return child;
    }
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapUp: (details) {
        if (showLineRects == null || _isDragging) return;
        showLineRects!.forEach((key, rect) {
          if (rect.contains(details.localPosition)) {
            controller.notifyEvent(LyricEvent.tapLine, key);
            return;
          }
        });
      },
      onVerticalDragDown: (details) {
        _isDragging = true;
        stopFlingController();
        _activeResumeDebouncer.dispose();
      },
      onVerticalDragStart: (_) {
        controller.isSelectingNotifier.value = true;
      },
      onVerticalDragUpdate: (details) {
        if (style.selectionAutoResumeMode ==
            SelectionAutoResumeMode.selecting) {
          scheduleResumeSelectedLine();
        }
        setDragTranslationY(scrollY - details.delta.dy);
      },
      onVerticalDragCancel: () {
        _isDragging = false;
        _scheduleResumeActiveLine();
      },
      onVerticalDragEnd: (details) {
        _activeResumeDebouncer.dispose();
        _selecteResumeDebouncer.dispose();
        _isDragging = false;
        final velocity = -details.velocity.pixelsPerSecond.dy;
        _flingController.animateWith(
          ClampingScrollSimulation(
            position: dragScrollY ?? 0,
            velocity: velocity,
          ),
        );
      },
      onTap: () {},
      child: child,
    );
  }

  @override
  void dispose() {
    _flingController.dispose();
    _activeResumeDebouncer.dispose();
    _selecteResumeDebouncer.dispose();
    _activeResumeDebouncer.dispose();
    controller.unregisterEvent(LyricEvent.stopSelection, _stopSelection);
    super.dispose();
  }
}

class Debouncer {
  Debouncer();

  Timer? _timer;

  void call(Duration delay, void Function() action) {
    _timer?.cancel();
    _timer = Timer(delay, action);
  }

  void dispose() {
    _timer?.cancel();
  }
}
