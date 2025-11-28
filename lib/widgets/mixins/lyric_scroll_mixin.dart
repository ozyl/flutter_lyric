import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_lyric/core/lyric_controller.dart';
import 'package:flutter_lyric/core/lyric_style.dart';
import 'package:flutter_lyric/render/lyric_layout.dart';
import 'package:flutter_lyric/widgets/mixins/lyric_layout_mixin.dart';

/// 负责歌词滚动动画控制的 Mixin
mixin LyricScrollMixin<T extends StatefulWidget>
    on State<T>, TickerProviderStateMixin<T>, LyricLayoutMixin<T> {
  @override
  LyricController get controller;
  @override
  LyricStyle get style;
  @override
  Size get lyricSize;
  @override
  LyricLayout? get layout;
  ValueNotifier<double> get scrollYNotifier;

  double? get dragScrollY;
  set dragScrollY(double? value);

  late final AnimationController _scrollController;
  Animation<double>? _translationAnimation;

  @override
  void initState() {
    super.initState();
    _scrollController =
        AnimationController(vsync: this, duration: style.scrollDuration)
          ..addListener(() {
            final value = _translationAnimation?.value;
            if (!mounted || value == null || value == scrollY) {
              return;
            }
            scrollY = value;
          });
    controller.activeIndexNotifiter.addListener(playIndexListener);
  }

  double get scrollY => scrollYNotifier.value;
  set scrollY(double value) {
    scrollYNotifier.value = value;
  }

  /// 播放索引变化监听
  void playIndexListener() {
    updateScrollY();
  }

  /// 根据偏移量计算动画时长
  Duration calculateAnimationDuration(double offset) {
    var duration = style.scrollDuration;
    if (style.scrollDurations.isNotEmpty == true) {
      for (var entry in style.scrollDurations.entries) {
        if (offset >= entry.key) {
          duration = entry.value;
        } else {
          break;
        }
      }
    }
    return duration;
  }

  calcActiveLineOffsetY() {
    final l = layout;
    if (l == null) {
      return 0;
    }
    final offset = l.lineOffsetY(
        controller.activeIndexNotifiter.value,
        controller.activeIndexNotifiter.value,
        l.activeAnchorPosition,
        style.activeAlignment);
    if (l.activeAnchorPosition < l.selectionAnchorPosition) {
      final lh = l.getLineHeight(true, controller.activeIndexNotifiter.value);
      final anchorOffset = l.anchorOffsetY(
          controller.activeIndexNotifiter.value,
          true,
          lh,
          style.selectionAlignment);
      final maxOffset = contentHeight -
          style.contentPadding.vertical -
          l.selectionAnchorPosition -
          (lh - anchorOffset);
      return min(offset, maxOffset);
    }
    return offset;
  }

  /// 更新偏移Y值
  void updateScrollY({bool animate = true}) {
    final currentLayout = layout;
    if (currentLayout != null) {
      final target = dragScrollY ?? calcActiveLineOffsetY();
      if (!animate) {
        if (_scrollController.isAnimating) {
          _scrollController.stop();
        }
        scrollY = target;
        return;
      }
      if (_scrollController.isAnimating) {
        _scrollController.stop();
      }
      final offset = (scrollY - target).abs();
      if (offset < 0.1) {
        scrollY = target;
        return;
      }
      // 根据偏移量动态计算动画时长
      final animationDuration = calculateAnimationDuration(offset);
      _scrollController.duration = animationDuration;
      if (animationDuration == Duration.zero) {
        scrollY = target;
        return;
      }
      final curvedAnimation = CurvedAnimation(
        parent: _scrollController,
        curve: style.scrollCurve,
      );
      _translationAnimation = Tween<double>(
        begin: scrollY,
        end: target,
      ).animate(curvedAnimation);
      _scrollController.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    controller.activeIndexNotifiter.removeListener(playIndexListener);
    super.dispose();
  }
}
