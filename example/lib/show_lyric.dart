// @dart=3.8

import 'package:flutter/material.dart';
import 'package:flutter_lyric/flutter_lyric.dart';
import 'demo_presets.dart';
import 'studio_theme.dart';

/// The stage only presents a preset. Drafts and playback live outside the view.
class ShowLyric extends StatelessWidget {
  const ShowLyric({
    super.key,
    required this.controller,
    required this.demo,
    required this.preset,
    this.onLineTap,
    this.original = false,
    this.showGuide = false,
  });
  final LyricController controller;
  final DemoPreset demo;
  final LyricPreset preset;
  final ValueChanged<LyricLineDetails>? onLineTap;
  final bool original;
  final bool showGuide;

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(24),
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 450),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: demo.background,
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            right: -120,
            top: -120,
            child: IgnorePointer(
              child: Container(
                width: 420,
                height: 420,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      demo.accent.withValues(alpha: .13),
                      demo.accent.withValues(alpha: 0),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            right: -90,
            bottom: -130,
            child: IgnorePointer(
              child: Container(
                width: 340,
                height: 340,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white.withValues(alpha: .05),
                    width: 1,
                  ),
                ),
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 22, 18, 0),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          StudioLabel(
                            original ? 'ORIGINAL / 原始配置' : 'LIVE STAGE / 实时舞台',
                            color: Colors.white54,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            demo.name,
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Tooltip(
                      message: preset.displayMode == LyricDisplayMode.activeLine
                          ? '单行模式'
                          : '多行模式',
                      child: Icon(
                        preset.displayMode == LyricDisplayMode.activeLine
                            ? Icons.short_text_rounded
                            : Icons.notes_rounded,
                        color: demo.accent,
                        size: 24,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) => Stack(
                    fit: StackFit.expand,
                    children: [
                      LyricView(
                        controller: controller,
                        preset: preset.copyWith(
                          selectionBackgroundBuilder: selectionBackground,
                          selectionForegroundBuilder: selectionForeground,
                        ),
                        onLineTap: onLineTap,
                      ),
                      if (showGuide)
                        Positioned(
                          left: 0,
                          right: 0,
                          top: preset.activeAnchor
                              .resolve(constraints.maxHeight)
                              .clamp(0, constraints.maxHeight - 1),
                          child: IgnorePointer(
                            child: Container(
                              height: 1,
                              color: demo.accent.withValues(alpha: .55),
                            ),
                          ),
                        ),
                      if (showGuide)
                        Positioned(
                          right: 10,
                          top:
                              (preset.activeAnchor.resolve(
                                        constraints.maxHeight,
                                      ) -
                                      20)
                                  .clamp(0, constraints.maxHeight - 20),
                          child: IgnorePointer(
                            child: Text(
                              'ANCHOR',
                              style: TextStyle(
                                fontSize: 8,
                                letterSpacing: 1.5,
                                color: demo.accent,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 10, 24, 20),
                child: Row(
                  children: [
                    Container(
                      width: 5,
                      height: 5,
                      decoration: BoxDecoration(
                        color: demo.accent,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        preset.interactive ? '滑动探索 · 轻点歌词跳转' : '跟随播放 · 沉浸聆听',
                        style: const TextStyle(
                          color: Colors.white54,
                          fontSize: 10,
                        ),
                      ),
                    ),
                    ValueListenableBuilder<int?>(
                      valueListenable: controller.activeLineIndexListenable,
                      builder: (_, index, _) => Text(
                        '${((index ?? -1) + 1).toString().padLeft(2, '0')} / ${controller.document?.lines.length ?? 0}',
                        style: const TextStyle(
                          color: Colors.white38,
                          fontSize: 10,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}

Widget selectionBackground(
  BuildContext context,
  LyricSelectionDetails details,
) => Stack(
  children: [
    Positioned.fromRect(
      rect: details.lineRect,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: .07),
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    ),
  ],
);

Widget selectionForeground(
  BuildContext context,
  LyricSelectionDetails details,
) => Stack(
  children: [
    Positioned(
      right: 8,
      top: details.anchorY - 20,
      height: 40,
      child: Material(
        color: const Color(0xE6333D35),
        borderRadius: BorderRadius.circular(20),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(width: 12),
            Text(
              '${details.line.seekPosition.inMinutes}:${(details.line.seekPosition.inSeconds % 60).toString().padLeft(2, '0')}',
              style: const TextStyle(color: Colors.white70, fontSize: 10),
            ),
            IconButton(
              tooltip: '播放这一句',
              onPressed: details.onTap,
              icon: const Icon(
                Icons.play_arrow_rounded,
                color: Colors.white,
                size: 20,
              ),
            ),
            IconButton(
              tooltip: '跟随播放',
              onPressed: details.resumeFollow,
              icon: const Icon(
                Icons.my_location_rounded,
                color: Colors.white70,
                size: 18,
              ),
            ),
          ],
        ),
      ),
    ),
  ],
);
