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

final issue41DemoStylePresets = <String, LyricStyle>{
  'Issue #41 Gradient': issue41HighlightOpacityDemo,
};
