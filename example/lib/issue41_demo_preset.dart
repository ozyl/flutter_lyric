// @dart=3.8

import 'package:flutter/material.dart';
import 'package:flutter_lyric/flutter_lyric.dart';

/// Issue #41 演示样式：active 文字半透明红色，高亮为饱和黄橙渐变。
/// 未唱到的字应显示淡红色，已唱到的字显示高亮渐变。
// Keep the regression fixture independent from evolving built-in styles.
final issue41HighlightOpacityDemo = LyricPreset(
  textStyle: const TextStyle(fontSize: 14, color: Color(0xB3FFFFFF)),
  selectedTextColor: const Color(0xFFFFFFFF),
  selectedTranslationTextColor: const Color(0xFFFFFFFF),
  textAlign: TextAlign.start,
  contentAlignment: LyricContentAlignment.start,
  activeAnchor: const LyricAnchor.fraction(
    .3,
    target: LyricAnchorTarget.mainText,
  ),
  selectionAnchor: const LyricAnchor.fraction(
    .5,
    target: LyricAnchorTarget.mainText,
  ),
  activeTextStyle: TextStyle(
    fontSize: 15,
    height: 1.2,
    fontWeight: FontWeight.w600,
    color: Colors.red.withValues(alpha: 0.25),
  ),
  highlight: const LyricHighlight.gradient(
    LinearGradient(colors: [Color(0xFFFFEB3B), Color(0xFFFF9800)]),
    tailFadeWidth: 48,
  ),
  activeTranslationTextStyle: TextStyle(
    color: Colors.white.withValues(alpha: 0.8),
  ),
);

/// 演示用时长：单行切换距离通常只有几十 px，需抬高最小时长才能看出 curve 差异。
Duration _demoScrollDuration(
  double offset, {
  int minMs = 900,
  int maxMs = 1800,
}) {
  return Duration(
    milliseconds: (minMs + offset * 1.5).clamp(minMs, maxMs).round(),
  );
}

/// 匀速 — 对比基准，速度恒定。
LyricAnimation _issue41ScrollLinear(double offset) {
  return LyricAnimation(
    duration: _demoScrollDuration(offset),
    curve: Curves.linear,
  );
}

/// 先慢后快 — easeIn 特征明显。
LyricAnimation _issue41ScrollEaseIn(double offset) {
  return LyricAnimation(
    duration: _demoScrollDuration(offset),
    curve: Curves.easeInCubic,
  );
}

/// 先快后慢 — easeOut 特征明显。
LyricAnimation _issue41ScrollEaseOut(double offset) {
  return LyricAnimation(
    duration: _demoScrollDuration(offset),
    curve: Curves.easeOutCubic,
  );
}

/// 冲过终点再回弹 — overshoot 非常明显。
LyricAnimation _issue41ScrollOvershoot(double offset) {
  return LyricAnimation(
    duration: _demoScrollDuration(offset, minMs: 1000, maxMs: 2000),
    curve: Curves.easeOutBack,
  );
}

/// 末端弹跳 — bounceOut 特征明显。
LyricAnimation _issue41ScrollBounce(double offset) {
  return LyricAnimation(
    duration: _demoScrollDuration(offset, minMs: 1100, maxMs: 2200),
    curve: Curves.bounceOut,
  );
}

/// 弹簧振荡 — elasticOut 需要更长时长才能看到回弹。
LyricAnimation _issue41ScrollElastic(double offset) {
  return LyricAnimation(
    duration: _demoScrollDuration(offset, minMs: 1200, maxMs: 2400),
    curve: Curves.elasticOut,
  );
}

final issue41DemoPresets = <String, LyricPreset>{
  'Issue #41 Gradient': issue41HighlightOpacityDemo,
  'Scroll · Linear': issue41HighlightOpacityDemo.copyWith(
    scrollAnimation: LyricScrollAnimation.custom(_issue41ScrollLinear),
  ),
  'Scroll · Ease In': issue41HighlightOpacityDemo.copyWith(
    scrollAnimation: LyricScrollAnimation.custom(_issue41ScrollEaseIn),
  ),
  'Scroll · Ease Out': issue41HighlightOpacityDemo.copyWith(
    scrollAnimation: LyricScrollAnimation.custom(_issue41ScrollEaseOut),
  ),
  'Scroll · Overshoot': issue41HighlightOpacityDemo.copyWith(
    scrollAnimation: LyricScrollAnimation.custom(_issue41ScrollOvershoot),
  ),
  'Scroll · Bounce': issue41HighlightOpacityDemo.copyWith(
    scrollAnimation: LyricScrollAnimation.custom(_issue41ScrollBounce),
  ),
  'Scroll · Elastic': issue41HighlightOpacityDemo.copyWith(
    scrollAnimation: LyricScrollAnimation.custom(_issue41ScrollElastic),
  ),
};
