import 'dart:async';
import 'dart:math' show max;

import 'package:flutter/material.dart';
import 'package:flutter_lyric/core/lyric_controller.dart';
import 'package:flutter_lyric/core/lyric_style.dart';
import 'package:flutter_lyric/render/lyric_layout.dart';

/// 负责歌词布局计算和状态管理的 Mixin
mixin LyricLayoutMixin<T extends StatefulWidget> on State<T> {
  LyricController get controller;
  LyricStyle get style;
  Size get lyricSize;
  set lyricSize(Size value);
  LyricLayout? get layout;
  set layout(LyricLayout? value);

  var contentHeight = 0.0;

  @override
  void dispose() {
    controller.activeIndexNotifiter.removeListener(updateTotalHeight);
    controller.lyricNotifier.removeListener(computeLyricLayout);
    PaintingBinding.instance.systemFonts.removeListener(systemFontsDidChange);
    super.dispose();
  }

  onStyleChange() {
    final l = layout;
    if (l == null) {
      computeLyricLayout();
      return;
    }
    final oldStyle = l.style;
    final newStyle = style;
    if (oldStyle == newStyle) return;
    layout = l.copyWith(newStyle);
    final comparison = oldStyle.compareTo(newStyle);
    if (comparison == RenderComparison.identical) {
      return;
    }
    if (comparison == RenderComparison.layout) {
      computeLyricLayout();
      return;
    }
    if (comparison == RenderComparison.paint) {
      layout?.metrics.forEach((element) {
        element.textPainter.text =
            TextSpan(text: element.line.text, style: newStyle.textStyle);
        element.activeTextPainter.text =
            TextSpan(text: element.line.text, style: newStyle.activeStyle);
        element.translationTextPainter.text = TextSpan(
            text: element.line.translation, style: newStyle.translationStyle);
      });
      setState(() {});
    }
  }

  @override
  void initState() {
    PaintingBinding.instance.systemFonts.addListener(systemFontsDidChange);
    controller.activeIndexNotifiter.addListener(() {
      scheduleMicrotask(() {
        updateTotalHeight();
      });
    });
    controller.selectedIndexNotifier.addListener(() {
      updateSelection();
    });
    WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
      controller.lyricNotifier.addListener(computeLyricLayout);
    });
    super.initState();
  }

  void updateTotalHeight() {
    contentHeight =
        layout?.contentHeight(controller.activeIndexNotifiter.value) ?? 0;
  }

  systemFontsDidChange() {
    if (layout == null) return;
    onLayoutChange(LyricLayout.updatePainters(layout!));
  }

  onLayoutChange(LyricLayout layout) {
    this.layout = layout;
    updateSelection();
    updateTotalHeight();
    if (mounted) {
      setState(() {});
    }
  }

  /// 计算歌词布局
  void computeLyricLayout() {
    final lyricModel = controller.lyricNotifier.value;
    if (lyricModel == null) {
      return;
    }
    final computedLayout = LyricLayout.compute(
      lyricModel,
      style,
      lyricSize,
    );
    controller.anchorPositionNotifier.value =
        computedLayout.selectionAnchorPosition;
    onLayoutChange(computedLayout);
  }

  void updateSelection() {
    final isHighlight = controller.activeIndexNotifiter.value ==
        controller.selectedIndexNotifier.value;
    scheduleMicrotask(() {
      controller.selectedLineHeightNotifier.value = layout?.getLineHeight(
            isHighlight,
            controller.selectedIndexNotifier.value,
          ) ??
          0;
    });
    final currentLine = layout?.metrics[controller.selectedIndexNotifier.value];
    controller.selectedMaxWidth = max(
      (isHighlight ? currentLine?.activeWidth : currentLine?.width) ?? 0,
      currentLine?.translationWidth ?? 0,
    );
    controller.anchorAlignOffsetY = layout?.anchorAdjustmentOffsetY(
          controller.selectedIndexNotifier.value,
          controller.activeIndexNotifiter.value,
        ) ??
        0;
  }
}
