import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_lyric/core/lyric_controller.dart';
import 'package:flutter_lyric/render/lyric_painter.dart';
import 'package:flutter_lyric/widgets/mixins/lyric_line_highlight.dart';
import 'package:flutter_lyric/widgets/mixins/lyric_line_switch_mixin.dart';

import '../core/lyric_style.dart';
import '../render/lyric_layout.dart';
import 'mixins/lyric_layout_mixin.dart';
import 'mixins/lyric_mask_mixin.dart';
import 'mixins/lyric_scroll_mixin.dart';
import 'mixins/lyric_touch_mixin.dart';

class LyricView extends StatefulWidget {
  final LyricController controller;
  final double? width;
  final double? height;
  const LyricView({
    Key? key,
    required this.controller,
    this.width,
    this.height,
  }) : super(key: key);

  @override
  State<LyricView> createState() => _LyricViewState();
}

class _LyricViewState extends State<LyricView>
    with
        TickerProviderStateMixin,
        LyricLayoutMixin,
        LyricScrollMixin,
        LyricMaskMixin,
        LyricTouchMixin,
        LyricLineHightlightMixin,
        LyricLineSwitchMixin {
  // 提供 mixin 需要的属性访问
  @override
  LyricController get controller => widget.controller;

  @override
  LyricStyle get style => controller.styleNotifier.value;

  // 布局相关状态
  @override
  LyricLayout? layout;

  @override
  var lyricSize = Size.zero;

  // 动画相关状态
  @override
  final scrollYNotifier = ValueNotifier<double>(0.0);

  @override
  void onLayoutChange(LyricLayout layout) {
    super.onLayoutChange(layout);
    updateHighlightWidth();
    updateScrollY(animate: false);
  }

  @override
  Widget build(BuildContext context) {
    return wrapTouchWidget(
      context,
      SizedBox(
        width: widget.width ?? double.infinity,
        height: widget.height ?? double.infinity,
        child: Padding(
          padding: style.contentPadding.copyWith(top: 0, bottom: 0),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final size = Size(constraints.maxWidth, constraints.maxHeight);
              if (size.width != lyricSize.width ||
                  size.height != lyricSize.height) {
                lyricSize = size;
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  computeLyricLayout();
                });
              }
              if (layout == null) return const SizedBox.shrink();
              Widget result = buildLineSwitch((context, switchState) {
                return buildActiveHighlightWidth((double value) {
                  return ValueListenableBuilder(
                      valueListenable: scrollYNotifier,
                      builder: (context, double scrollY, child) {
                        return CustomPaint(
                          painter: LyricPainter(
                            layout: layout!,
                            onShowLineRectsChange: (rects) {
                              showLineRects = rects;
                            },
                            style: style,
                            playIndex: controller.activeIndexNotifiter.value,
                            activeHighlightWidth: value,
                            isSelecting: controller.isSelectingNotifier.value,
                            scrollY: scrollY,
                            onAnchorIndexChange: (index) {
                              scheduleMicrotask(() {
                                controller.selectedIndexNotifier.value = index;
                              });
                            },
                            switchState: switchState,
                          ),
                          size: lyricSize,
                        );
                      });
                });
              });
              result = wrapMaskIfNeed(result);
              return result;
            },
          ),
        ),
      ),
    );
  }
}
