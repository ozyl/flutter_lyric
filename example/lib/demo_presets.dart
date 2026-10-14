// @dart=3.8

import 'package:flutter/material.dart';
import 'package:flutter_lyric/flutter_lyric.dart';

/// Gallery metadata stays separate from the library's reusable configuration.
class DemoPreset {
  const DemoPreset({
    required this.id,
    required this.name,
    required this.caption,
    required this.tag,
    required this.accent,
    required this.background,
    required this.preset,
  });
  final String id;
  final String name;
  final String caption;
  final String tag;
  final Color accent;
  final List<Color> background;
  final LyricPreset preset;
}

LyricPreset _style({
  double size = 23,
  double activeSize = 30,
  Color accent = const Color(0xFFD5EDAD),
  TextAlign align = TextAlign.start,
  double anchor = .4,
  double spacing = 26,
  FontWeight weight = FontWeight.w600,
}) => LyricPresets.moss.copyWith(
  textStyle: TextStyle(
    fontSize: size,
    color: const Color(0x66FFFFFF),
    height: 1.35,
  ),
  activeTextStyle: TextStyle(
    fontSize: activeSize,
    color: const Color(0x88FFFFFF),
    fontWeight: weight,
    height: 1.35,
  ),
  translationTextStyle: const TextStyle(
    fontSize: 12,
    color: Color(0x66FFFFFF),
    height: 1.5,
  ),
  activeTranslationTextStyle: const TextStyle(
    fontSize: 13,
    color: Color(0xCCFFFFFF),
    height: 1.5,
  ),
  textAlign: align,
  contentAlignment: align == TextAlign.center
      ? LyricContentAlignment.center
      : align == TextAlign.end
      ? LyricContentAlignment.end
      : LyricContentAlignment.start,
  padding: const EdgeInsets.symmetric(horizontal: 28),
  activeAnchor: LyricAnchor.fraction(
    anchor,
    target: LyricAnchorTarget.mainText,
  ),
  lineSpacing: spacing,
  translationSpacing: 9,
  highlight: LyricHighlight.solid(accent, tailFadeWidth: 28),
  countdown: LyricCountdown(
    dotSize: activeSize * .27,
    dotSpacing: activeSize * .32,
    height: activeSize,
    spacing: spacing,
    color: accent,
    breathDuration: const Duration(milliseconds: 1600),
  ),
  edgeFade: const LyricEdgeFade.fraction(top: .12, bottom: .2),
  scrollAnimation: const LyricScrollAnimation.fixed(
    duration: Duration(milliseconds: 550),
  ),
);

final demoPresets = <DemoPreset>[
  DemoPreset(
    id: 'apple-music',
    name: 'Apple Music',
    caption: '换行位置稳定，歌词依次跟进，字词轻盈悬浮。',
    tag: 'FLOAT',
    accent: const Color(0xFFFFCCD5),
    background: const [Color(0xFF603B46), Color(0xFF251E29)],
    preset: LyricPresets.appleMusic,
  ),
  DemoPreset(
    id: 'moss',
    name: '苔原',
    caption: '轻盈浮升，像呼吸一样展开。',
    tag: 'ORGANIC',
    accent: const Color(0xFFD5EDAD),
    background: const [Color(0xFF273E36), Color(0xFF101F1C)],
    preset: LyricPresets.moss,
  ),
  DemoPreset(
    id: 'aurora',
    name: '极光',
    caption: '新旧句沿弧线交接，光色流动。',
    tag: 'GRADIENT',
    accent: const Color(0xFF90E9EE),
    background: const [Color(0xFF283957), Color(0xFF17172E)],
    preset: LyricPresets.aurora,
  ),
  DemoPreset(
    id: 'cascade',
    name: '瀑布',
    caption: '三段落位，行间层层跟进。',
    tag: 'CASCADE',
    accent: const Color(0xFF9BDCEB),
    background: const [Color(0xFF294752), Color(0xFF17272F)],
    preset: LyricPresets.cascade,
  ),
  DemoPreset(
    id: 'pulse',
    name: '跃动',
    caption: '弹簧回落与逐字上弹，跳出重音。',
    tag: 'PULSE',
    accent: const Color(0xFFFFBE98),
    background: const [Color(0xFF633E3D), Color(0xFF2C2029)],
    preset: LyricPresets.pulse,
  ),
  DemoPreset(
    id: 'editorial',
    name: '字刊',
    caption: '纸页先滑入，大字随后显现。',
    tag: 'EDITORIAL',
    accent: const Color(0xFFFFD2AD),
    background: const [Color(0xFF583F36), Color(0xFF291F20)],
    preset:
        _style(
          size: 25,
          activeSize: 38,
          accent: const Color(0xFFFFD2AD),
          anchor: .32,
          spacing: 34,
          weight: FontWeight.w800,
        ).copyWith(
          highlight: const LyricHighlight.none(),
          lineTransition: LyricLineTransitions.paper,
        ),
  ),
  DemoPreset(
    id: 'cinema',
    name: '银幕',
    caption: '雾化交叠，先对焦再进入下一幕。',
    tag: 'SINGLE LINE',
    accent: const Color(0xFFE9D9B4),
    background: const [Color(0xFF393A38), Color(0xFF171B1C)],
    preset: LyricPresets.cinema,
  ),
  DemoPreset(
    id: 'neon',
    name: '霓虹',
    caption: '镜头推进，让副歌从虚焦中点亮。',
    tag: 'KARAOKE',
    accent: const Color(0xFFF4A3EB),
    background: const [Color(0xFF432346), Color(0xFF211B32)],
    preset:
        _style(
          align: TextAlign.center,
          activeSize: 34,
          accent: const Color(0xFFF4A3EB),
          spacing: 30,
          anchor: .46,
        ).copyWith(
          highlight: const LyricHighlight.gradient(
            LinearGradient(colors: [Color(0xFFF49AFF), Color(0xFF8CEEFF)]),
            tailFadeWidth: 16,
          ),
          scrollAnimation: const LyricScrollAnimation.fixed(
            duration: Duration(milliseconds: 650),
            curve: Curves.easeOutCubic,
          ),
          lineTransition: LyricLineTransitions.zoom,
        ),
  ),
  DemoPreset(
    id: 'letter',
    name: '来信',
    caption: '钟摆轻摇，温柔落在句尾。',
    tag: 'TRAILING',
    accent: const Color(0xFFF2C2B2),
    background: const [Color(0xFF54414A), Color(0xFF29232F)],
    preset: _style(
      align: TextAlign.end,
      size: 19,
      activeSize: 25,
      accent: const Color(0xFFF2C2B2),
      spacing: 24,
      weight: FontWeight.w400,
    ).copyWith(lineTransition: LyricLineTransitions.pendulum),
  ),
  DemoPreset(
    id: 'terminal',
    name: '频率',
    caption: '三段跃迁，把切句变成节奏信号。',
    tag: 'MONO',
    accent: const Color(0xFFB5F58A),
    background: const [Color(0xFF263C32), Color(0xFF121F1C)],
    preset:
        _style(
          size: 16,
          activeSize: 19,
          accent: const Color(0xFFB5F58A),
          spacing: 16,
          anchor: .35,
        ).copyWith(
          textStyle: const TextStyle(
            fontSize: 16,
            color: Color(0x77FFFFFF),
            fontFamily: 'monospace',
          ),
          activeTextStyle: const TextStyle(
            fontSize: 19,
            color: Color(0x88FFFFFF),
            fontFamily: 'monospace',
            fontWeight: FontWeight.bold,
          ),
          scrollAnimation: const LyricScrollAnimation.fixed(
            duration: Duration(milliseconds: 180),
            curve: Curves.linear,
          ),
          lineTransition: LyricLineTransitions.step.copyWith(
            enterDuration: const Duration(milliseconds: 330),
            exitDuration: const Duration(milliseconds: 180),
          ),
        ),
  ),
  DemoPreset(
    id: 'float',
    name: '浮游',
    caption: '余韵斜向漂移，字词缓慢悬浮。',
    tag: 'AMBIENT',
    accent: const Color(0xFFD6D3FC),
    background: const [Color(0xFF3B405E), Color(0xFF222738)],
    preset: LyricPresets.drift,
  ),
];
