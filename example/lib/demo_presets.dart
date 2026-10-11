import 'package:flutter/material.dart';
import 'package:flutter_lyric/flutter_lyric.dart';
import 'issue41_demo_preset.dart';

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
    this.lab = false,
  });
  final String id;
  final String name;
  final String caption;
  final String tag;
  final Color accent;
  final List<Color> background;
  final LyricPreset preset;
  final bool lab;
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
  edgeFade: const LyricEdgeFade.fraction(top: .12, bottom: .2),
  scrollAnimation: const LyricScrollAnimation.fixed(
    duration: Duration(milliseconds: 550),
  ),
);

final demoPresets = <DemoPreset>[
  DemoPreset(
    id: 'moss',
    name: '苔原',
    caption: '松弛留白，逐字生长。',
    tag: 'ORGANIC',
    accent: const Color(0xFFD5EDAD),
    background: const [Color(0xFF273E36), Color(0xFF101F1C)],
    preset: LyricPresets.moss,
  ),
  DemoPreset(
    id: 'aurora',
    name: '极光',
    caption: '冷色渐变，流动的声场。',
    tag: 'GRADIENT',
    accent: const Color(0xFF90E9EE),
    background: const [Color(0xFF283957), Color(0xFF17172E)],
    preset: LyricPresets.aurora,
  ),
  DemoPreset(
    id: 'editorial',
    name: '字刊',
    caption: '大字、左对齐，像一页音乐杂志。',
    tag: 'EDITORIAL',
    accent: const Color(0xFFFFD2AD),
    background: const [Color(0xFF583F36), Color(0xFF291F20)],
    preset: _style(
      size: 25,
      activeSize: 38,
      accent: const Color(0xFFFFD2AD),
      anchor: .32,
      spacing: 34,
      weight: FontWeight.w800,
    ).copyWith(highlight: const LyricHighlight.none()),
  ),
  DemoPreset(
    id: 'cinema',
    name: '银幕',
    caption: '一行主角，一整个世界。',
    tag: 'SINGLE LINE',
    accent: const Color(0xFFE9D9B4),
    background: const [Color(0xFF393A38), Color(0xFF171B1C)],
    preset: LyricPresets.cinema,
  ),
  DemoPreset(
    id: 'neon',
    name: '霓虹',
    caption: '高饱和逐字光谱，点亮副歌。',
    tag: 'KARAOKE',
    accent: const Color(0xFFF4A3EB),
    background: const [Color(0xFF432346), Color(0xFF211B32)],
    preset:
        _style(
          align: TextAlign.center,
          activeSize: 34,
          spacing: 30,
          anchor: .46,
        ).copyWith(
          highlight: const LyricHighlight.gradient(
            LinearGradient(colors: [Color(0xFFF49AFF), Color(0xFF8CEEFF)]),
            tailFadeWidth: 16,
          ),
          scrollAnimation: const LyricScrollAnimation.fixed(
            duration: Duration(milliseconds: 700),
            curve: Curves.easeOutBack,
          ),
        ),
  ),
  DemoPreset(
    id: 'letter',
    name: '来信',
    caption: '轻盈靠右，温柔回应。',
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
    ),
  ),
  DemoPreset(
    id: 'terminal',
    name: '频率',
    caption: '紧凑排布，把节奏变成信号。',
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
          lineTransition: const LyricLineTransition.none(),
        ),
  ),
  DemoPreset(
    id: 'float',
    name: '浮游',
    caption: '宽松居中，慢一点也很好。',
    tag: 'AMBIENT',
    accent: const Color(0xFFD6D3FC),
    background: const [Color(0xFF3B405E), Color(0xFF222738)],
    preset:
        _style(
          size: 18,
          activeSize: 26,
          align: TextAlign.center,
          accent: const Color(0xFFD6D3FC),
          spacing: 44,
          anchor: .5,
          weight: FontWeight.w400,
        ).copyWith(
          scrollAnimation: const LyricScrollAnimation.fixed(
            duration: Duration(milliseconds: 1100),
            curve: Curves.easeInOutCubic,
          ),
          lineTransition: const LyricLineTransition(
            enterDuration: Duration(milliseconds: 650),
            exitDuration: Duration(milliseconds: 650),
          ),
          edgeFade: const LyricEdgeFade.fraction(top: .25, bottom: .3),
        ),
  ),
  for (final entry in issue41DemoPresets.entries)
    DemoPreset(
      id: entry.key,
      name: entry.key == 'Issue #41 Gradient'
          ? 'Issue #41'
          : entry.key.replaceFirst('Scroll · ', ''),
      caption: entry.key == 'Issue #41 Gradient'
          ? '半透明底字 × 饱和渐变高亮'
          : 'Issue #41 · 自定义距离时长与曲线',
      tag: entry.key == 'Issue #41 Gradient' ? 'REGRESSION' : 'SCROLL CURVE',
      accent: const Color(0xFFFFCB77),
      background: const [Color(0xFF453B2D), Color(0xFF241F1C)],
      preset: entry.value,
      lab: true,
    ),
];
