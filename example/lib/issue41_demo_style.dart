import 'package:flutter/material.dart';
import 'package:flutter_lyric/core/lyric_style.dart';
import 'package:flutter_lyric/core/lyric_styles.dart';

/// Issue #41 演示样式：active 文字半透明红色，高亮为饱和黄橙渐变。
/// 未唱到的字应显示淡红色，已唱到的字显示高亮渐变。
final issue41HighlightOpacityDemo = LyricStyles.default2.copyWith(
  enableSwitchAnimation: true,
  activeStyle: TextStyle(
    fontSize: 15,
    height: 1.2,
    fontWeight: FontWeight.w600,
    color: Colors.red.withValues(alpha: 0.25),
  ),
  activeHighlightGradient: const LinearGradient(
    colors: [Color(0xFFFFEB3B), Color(0xFFFF9800)],
  ),
  activeHighlightTailGradientWidth: 48,
  translationActiveColor: Colors.white.withValues(alpha: 0.8),
);

/// 演示用时长：单行切换距离通常只有几十 px，需抬高最小时长才能看出 curve 差异。
Duration _demoScrollDuration(double offset, {int minMs = 900, int maxMs = 1800}) {
  return Duration(
    milliseconds: (minMs + offset * 1.5).clamp(minMs, maxMs).round(),
  );
}

/// 匀速 — 对比基准，速度恒定。
LyricScrollAnimationConfig _issue41ScrollLinear(double offset) {
  return LyricScrollAnimationConfig(
    duration: _demoScrollDuration(offset),
    curve: Curves.linear,
  );
}

/// 先慢后快 — easeIn 特征明显。
LyricScrollAnimationConfig _issue41ScrollEaseIn(double offset) {
  return LyricScrollAnimationConfig(
    duration: _demoScrollDuration(offset),
    curve: Curves.easeInCubic,
  );
}

/// 先快后慢 — easeOut 特征明显。
LyricScrollAnimationConfig _issue41ScrollEaseOut(double offset) {
  return LyricScrollAnimationConfig(
    duration: _demoScrollDuration(offset),
    curve: Curves.easeOutCubic,
  );
}

/// 冲过终点再回弹 — overshoot 非常明显。
LyricScrollAnimationConfig _issue41ScrollOvershoot(double offset) {
  return LyricScrollAnimationConfig(
    duration: _demoScrollDuration(offset, minMs: 1000, maxMs: 2000),
    curve: Curves.easeOutBack,
  );
}

/// 末端弹跳 — bounceOut 特征明显。
LyricScrollAnimationConfig _issue41ScrollBounce(double offset) {
  return LyricScrollAnimationConfig(
    duration: _demoScrollDuration(offset, minMs: 1100, maxMs: 2200),
    curve: Curves.bounceOut,
  );
}

/// 弹簧振荡 — elasticOut 需要更长时长才能看到回弹。
LyricScrollAnimationConfig _issue41ScrollElastic(double offset) {
  return LyricScrollAnimationConfig(
    duration: _demoScrollDuration(offset, minMs: 1200, maxMs: 2400),
    curve: Curves.elasticOut,
  );
}

final issue41DemoStylePresets = <String, LyricStyle>{
  'Issue #41 Gradient': issue41HighlightOpacityDemo,
  'Scroll · Linear': issue41HighlightOpacityDemo.copyWith(
    scrollAnimationBuilder: _issue41ScrollLinear,
  ),
  'Scroll · Ease In': issue41HighlightOpacityDemo.copyWith(
    scrollAnimationBuilder: _issue41ScrollEaseIn,
  ),
  'Scroll · Ease Out': issue41HighlightOpacityDemo.copyWith(
    scrollAnimationBuilder: _issue41ScrollEaseOut,
  ),
  'Scroll · Overshoot': issue41HighlightOpacityDemo.copyWith(
    scrollAnimationBuilder: _issue41ScrollOvershoot,
  ),
  'Scroll · Bounce': issue41HighlightOpacityDemo.copyWith(
    scrollAnimationBuilder: _issue41ScrollBounce,
  ),
  'Scroll · Elastic': issue41HighlightOpacityDemo.copyWith(
    scrollAnimationBuilder: _issue41ScrollElastic,
  ),
};
