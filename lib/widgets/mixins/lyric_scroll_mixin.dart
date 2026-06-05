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
  CurvedAnimation? _curvedAnimation;

  @override
  void initState() {
    super.initState();
    _scrollController =
        AnimationController(vsync: this, duration: style.scrollDuration)
          ..addListener(_onScrollAnimationTick)
          ..addStatusListener(_onScrollAnimationStatus);
    controller.registerEvent(LyricEvent.reset, _reset);
    controller.activeIndexNotifiter.addListener(playIndexListener);
  }

  void _onScrollAnimationTick() {
    final value = _translationAnimation?.value;
    if (!mounted || value == null || value == scrollY) {
      return;
    }
    scrollY = value;
  }

  void _onScrollAnimationStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed) {
      _disposeScrollAnimation();
    }
  }

  void _disposeScrollAnimation() {
    _translationAnimation = null;
    _curvedAnimation?.dispose();
    _curvedAnimation = null;
  }

  void _reset(dynamic _) {
    if (_scrollController.isAnimating) {
      _scrollController.stop();
    }
    _disposeScrollAnimation();
  }

  double get scrollY => scrollYNotifier.value;
  set scrollY(double value) {
    scrollYNotifier.value = value;
  }

  /// 播放索引变化监听
  void playIndexListener() {
    if (!mounted) {
      return;
    }
    updateScrollY();
  }

  /// 根据偏移量计算动画配置
  LyricScrollAnimationConfig calculateAnimationConfig(double offset) {
    final customConfig = style.scrollAnimationBuilder?.call(offset);
    if (customConfig != null) {
      return customConfig;
    }

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
    return LyricScrollAnimationConfig(
      duration: duration,
      curve: style.scrollCurve,
    );
  }

  double calcActiveLineOffsetY() {
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
    if (!mounted) {
      return;
    }
    final currentLayout = layout;
    if (currentLayout != null) {
      final target = dragScrollY ?? calcActiveLineOffsetY();
      if (!animate) {
        if (_scrollController.isAnimating) {
          _scrollController.stop();
        }
        _disposeScrollAnimation();
        scrollY = target;
        return;
      }
      if (_scrollController.isAnimating) {
        _scrollController.stop();
      }
      _disposeScrollAnimation();
      final offset = (scrollY - target).abs();
      if (offset < 0.1) {
        scrollY = target;
        return;
      }
      // 根据偏移量动态计算动画配置
      final animationConfig = calculateAnimationConfig(offset);
      _scrollController.duration = animationConfig.duration;
      if (animationConfig.duration == Duration.zero) {
        scrollY = target;
        return;
      }
      _curvedAnimation = CurvedAnimation(
        parent: _scrollController,
        curve: animationConfig.curve,
      );
      _translationAnimation = Tween<double>(
        begin: scrollY,
        end: target,
      ).animate(_curvedAnimation!);
      _scrollController.forward(from: 0);
    }
  }

  @override
  void dispose() {
    controller.unregisterEvent(LyricEvent.reset, _reset);
    controller.activeIndexNotifiter.removeListener(playIndexListener);
    _scrollController
      ..removeStatusListener(_onScrollAnimationStatus)
      ..stop();
    _disposeScrollAnimation();
    _scrollController.dispose();
    super.dispose();
  }
}
