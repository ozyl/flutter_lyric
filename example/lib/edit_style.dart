import 'package:flutter/material.dart';
import 'package:flutter_lyric/core/lyric_style.dart';

class EditStyle extends StatelessWidget {
  final LyricStyle style;
  final Function(LyricStyle) onStyleChanged;
  const EditStyle({
    super.key,
    required this.style,
    required this.onStyleChanged,
  });

  set style(LyricStyle value) {
    onStyleChanged(value);
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Material(
        color: Colors.transparent,
        child: Container(
          height: MediaQuery.of(context).size.height * 0.8,
          width: MediaQuery.of(context).size.width * 0.8,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white60,
            borderRadius: BorderRadius.circular(16),
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 24),
                Text(
                  'Lyric Style: ${(style.textStyle.fontSize ?? 16).toStringAsFixed(0)}',
                ),
                Slider(
                  value: style.textStyle.fontSize ?? 16,
                  min: 12,
                  max: 36,
                  divisions: 24,
                  label: (style.textStyle.fontSize ?? 16).toStringAsFixed(0),
                  onChanged: (value) {
                    style = style.copyWith(
                      textStyle: style.textStyle.copyWith(fontSize: value),
                    );
                  },
                ),
                const SizedBox(height: 16),
                Text(
                  'Active Lyric Style: ${(style.activeStyle.fontSize ?? 16).toStringAsFixed(0)}',
                ),
                Slider(
                  value: style.activeStyle.fontSize ?? 16,
                  min: 12,
                  max: 36,
                  divisions: 24,
                  label: (style.activeStyle.fontSize ?? 16).toStringAsFixed(0),
                  onChanged: (value) {
                    style = style.copyWith(
                      activeStyle: style.activeStyle.copyWith(fontSize: value),
                    );
                  },
                ),
                const SizedBox(height: 16),
                Text(
                  'Translation Lyric Style: ${(style.translationStyle.fontSize ?? 16).toStringAsFixed(0)}',
                ),
                Slider(
                  value: style.translationStyle.fontSize ?? 16,
                  min: 12,
                  max: 36,
                  divisions: 24,
                  label: (style.translationStyle.fontSize ?? 16)
                      .toStringAsFixed(0),
                  onChanged: (value) {
                    style = style.copyWith(
                      translationStyle: style.translationStyle.copyWith(
                        fontSize: value,
                      ),
                    );
                  },
                ),
                const SizedBox(height: 24),
                Text('Line Gap: ${style.lineGap.toStringAsFixed(0)}'),
                Slider(
                  value: style.lineGap,
                  min: 0,
                  max: 60,
                  divisions: 30,
                  label: style.lineGap.toStringAsFixed(0),
                  onChanged: (value) {
                    style = style.copyWith(lineGap: value);
                  },
                ),
                const SizedBox(height: 24),
                Text(
                  'Translation Line Gap: ${style.translationLineGap.toStringAsFixed(0)}',
                ),
                Slider(
                  value: style.translationLineGap,
                  min: 0,
                  max: 60,
                  divisions: 30,
                  label: style.translationLineGap.toStringAsFixed(0),
                  onChanged: (value) {
                    style = style.copyWith(translationLineGap: value);
                  },
                ),
                const SizedBox(height: 24),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Text('Line Text Alignment-'),
                        const SizedBox(width: 12),
                        DropdownButton<TextAlign>(
                          value: style.lineTextAlign,
                          items: const [
                            DropdownMenuItem(
                              value: TextAlign.left,
                              child: Text('Left'),
                            ),
                            DropdownMenuItem(
                              value: TextAlign.center,
                              child: Text('Center'),
                            ),
                            DropdownMenuItem(
                              value: TextAlign.right,
                              child: Text('Right'),
                            ),
                          ],
                          onChanged: (value) {
                            if (value == null) return;

                            style = style.copyWith(textAlign: value);
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        const Text('Content Alignment-'),
                        const SizedBox(width: 12),
                        DropdownButton<CrossAxisAlignment>(
                          value: style.contentAlignment,
                          items: const [
                            DropdownMenuItem(
                              value: CrossAxisAlignment.start,
                              child: Text('Start'),
                            ),
                            DropdownMenuItem(
                              value: CrossAxisAlignment.center,
                              child: Text('Center'),
                            ),
                            DropdownMenuItem(
                              value: CrossAxisAlignment.end,
                              child: Text('End'),
                            ),
                          ],
                          onChanged: (value) {
                            if (value == null) return;

                            style = style.copyWith(crossAxisAlignment: value);
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        const Text('Selection Anchor Alignment-'),
                        const SizedBox(width: 12),
                        DropdownButton<MainAxisAlignment>(
                          value: style.selectionAlignment,
                          items: const [
                            DropdownMenuItem(
                              value: MainAxisAlignment.start,
                              child: Text('Main Lyric'),
                            ),
                            DropdownMenuItem(
                              value: MainAxisAlignment.center,
                              child: Text('Center'),
                            ),
                            DropdownMenuItem(
                              value: MainAxisAlignment.end,
                              child: Text('Translation Lyric'),
                            ),
                          ],
                          onChanged: (value) {
                            if (value == null) return;

                            style = style.copyWith(highlightAlign: value);
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        const Text('Play Anchor Alignment-'),
                        const SizedBox(width: 12),
                        DropdownButton<MainAxisAlignment>(
                          value: style.activeAlignment,
                          items: const [
                            DropdownMenuItem(
                              value: MainAxisAlignment.start,
                              child: Text('Main Lyric'),
                            ),
                            DropdownMenuItem(
                              value: MainAxisAlignment.center,
                              child: Text('Center'),
                            ),
                            DropdownMenuItem(
                              value: MainAxisAlignment.end,
                              child: Text('Translation Lyric'),
                            ),
                          ],
                          onChanged: (value) {
                            if (value == null) return;

                            style = style.copyWith(activeAlignment: value);
                          },
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Text(
                  'Content Padding - Top: ${style.contentPadding.top.toStringAsFixed(0)}',
                ),
                Slider(
                  value: style.contentPadding.top,
                  min: 0,
                  max: 800,
                  divisions: 40,
                  label: style.contentPadding.top.toStringAsFixed(0),
                  onChanged: (value) {
                    style = style.copyWith(
                      contentPadding: style.contentPadding.copyWith(top: value),
                    );
                  },
                ),
                Text(
                  'Content Padding - Left: ${style.contentPadding.left.toStringAsFixed(0)}',
                ),
                Slider(
                  value: style.contentPadding.left,
                  min: 0,
                  max: 500,
                  divisions: 40,
                  label: style.contentPadding.left.toStringAsFixed(0),
                  onChanged: (value) {
                    style = style.copyWith(
                      contentPadding: style.contentPadding.copyWith(
                        left: value,
                      ),
                    );
                  },
                ),
                Text(
                  'Content Padding - Right: ${style.contentPadding.right.toStringAsFixed(0)}',
                ),
                Slider(
                  value: style.contentPadding.right,
                  min: 0,
                  max: 200,
                  divisions: 40,
                  label: style.contentPadding.right.toStringAsFixed(0),
                  onChanged: (value) {
                    style = style.copyWith(
                      contentPadding: style.contentPadding.copyWith(
                        right: value,
                      ),
                    );
                  },
                ),
                Text(
                  'Content Padding - Bottom: ${style.contentPadding.bottom.toStringAsFixed(0)}',
                ),
                Slider(
                  value: style.contentPadding.bottom,
                  min: 0,
                  max: 200,
                  divisions: 40,
                  label: style.contentPadding.bottom.toStringAsFixed(0),
                  onChanged: (value) {
                    style = style.copyWith(
                      contentPadding: style.contentPadding.copyWith(
                        bottom: value,
                      ),
                    );
                  },
                ),
                const SizedBox(height: 24),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Selection Anchor Position: ${(style.selectionAnchorPosition).toStringAsFixed(1)}',
                      ),
                      SizedBox(width: 30),
                      Text("Relative Value:"),
                      Checkbox(
                        value: style.selectionAnchorPosition <= 1,
                        onChanged: (value) {
                          style = style.copyWith(
                            anchorPosition: style.selectionAnchorPosition <= 1
                                ? 1.1
                                : 0,
                          );
                        },
                      ),
                    ],
                  ),
                ),
                Slider(
                  value: style.selectionAnchorPosition * 10,
                  min: style.selectionAnchorPosition > 1 ? 11 : 0,
                  max: style.selectionAnchorPosition > 1 ? 5000 : 10,
                  label: style.selectionAnchorPosition.toStringAsFixed(2),
                  divisions: 50,
                  onChanged: (value) {
                    style = style.copyWith(anchorPosition: value / 10);
                  },
                ),
                const SizedBox(height: 24),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Play Line Anchor Position: ${(style.activeAnchorPosition).toStringAsFixed(1)}',
                      ),
                      SizedBox(width: 30),
                      Text("Relative Value:"),
                      Checkbox(
                        value: style.activeAnchorPosition <= 1,
                        onChanged: (value) {
                          style = style.copyWith(
                            anchorPosition: style.activeAnchorPosition <= 1
                                ? 1.1
                                : 0,
                          );
                        },
                      ),
                    ],
                  ),
                ),
                Slider(
                  value: style.activeAnchorPosition * 10,
                  min: style.activeAnchorPosition > 1 ? 11 : 0,
                  max: style.activeAnchorPosition > 1 ? 5000 : 10,
                  label: style.activeAnchorPosition.toStringAsFixed(2),
                  divisions: 50,
                  onChanged: (value) {
                    style = style.copyWith(activeAnchorPosition: value / 10);
                  },
                ),
                const SizedBox(height: 24),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('Top/Bottom Fade'),
                      SizedBox(width: 30),
                      Text("Relative Value:"),
                      Checkbox(
                        value: style.isFadeRelative,
                        onChanged: (value) {
                          style = style.copyWith(
                            fadeRange: style.isFadeRelative
                                ? FadeRange(top: 1.1, bottom: 1.1)
                                : FadeRange(top: 0, bottom: 0),
                          );
                        },
                      ),
                    ],
                  ),
                ),
                if (!style.isFadeRelative) ...[
                  Row(
                    children: [
                      ConstrainedBox(
                        constraints: BoxConstraints(minWidth: 60),
                        child: Text("start"),
                      ),
                      Expanded(
                        child: Slider(
                          value: style.fadeRange?.top ?? 0,
                          min: 1.01,
                          max: 500,
                          divisions: 100,
                          label: style.fadeRange?.top.toStringAsFixed(2) ?? '0',
                          onChanged: (value) {
                            style = style.copyWith(
                              fadeRange: FadeRange(
                                top: value,
                                bottom: style.fadeRange?.bottom ?? 1,
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      ConstrainedBox(
                        constraints: BoxConstraints(minWidth: 60),
                        child: Text("end"),
                      ),
                      Expanded(
                        child: Slider(
                          value: style.fadeRange?.bottom ?? 1,
                          min: 1.001,
                          max: 500,
                          divisions: 100,
                          label:
                              style.fadeRange?.bottom.toStringAsFixed(2) ?? '1',
                          onChanged: (value) {
                            style = style.copyWith(
                              fadeRange: FadeRange(
                                top: style.fadeRange?.top ?? 0,
                                bottom: value,
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ],
                if (style.isFadeRelative)
                  RangeSlider(
                    values: RangeValues(
                      style.fadeRange?.top ?? 0,
                      1 - (style.fadeRange?.bottom ?? 1),
                    ),
                    labels: RangeLabels(
                      style.fadeRange?.top.toStringAsFixed(2) ?? '',
                      ((style.fadeRange?.bottom ?? 1)).toStringAsFixed(2),
                    ),
                    divisions: 100,
                    onChanged: (value) {
                      if (value.end < value.start) return;

                      style = style.copyWith(
                        fadeRange: FadeRange(
                          top: value.start,
                          bottom: 1 - value.end,
                        ),
                      );
                    },
                  ),
                const SizedBox(height: 24),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Scroll Animation Duration: ${style.scrollDuration.inMilliseconds.toStringAsFixed(0)}ms',
                      ),
                      SizedBox(width: 30),
                      Text("Fine Control:"),
                      Checkbox(
                        value: style.scrollDurations.isNotEmpty == true,
                        onChanged: (value) {
                          style = style.copyWith(
                            scrollDurationMap:
                                style.scrollDurations.isNotEmpty == true
                                ? {}
                                : {
                                    500: Duration(milliseconds: 500),
                                    1000: Duration(milliseconds: 1000),
                                  },
                          );
                        },
                      ),
                    ],
                  ),
                ),
                Slider(
                  value: style.scrollDuration.inMilliseconds.toDouble(),
                  min: 0,
                  max: 3000,
                  divisions: 100,
                  onChanged: (value) {
                    style = style.copyWith(
                      scrollDuration: Duration(milliseconds: value.toInt()),
                    );
                  },
                ),
                if (style.scrollDurations.isNotEmpty == true)
                  ...style.scrollDurations.entries.map((entry) {
                    return Row(
                      children: [
                        Text(
                          '${entry.key.toInt()}px-${entry.value.inMilliseconds.toStringAsFixed(0)}ms',
                        ),
                        Expanded(
                          child: Slider(
                            value: entry.value.inMilliseconds.toDouble(),
                            min: 0,
                            max: 3000,
                            divisions: 100,
                            label: entry.value.inMilliseconds.toStringAsFixed(
                              0,
                            ),
                            onChanged: (value) {
                              style = style.copyWith(
                                scrollDurationMap: {
                                  ...style.scrollDurations,
                                  entry.key: Duration(
                                    milliseconds: value.toInt(),
                                  ),
                                },
                              );
                            },
                          ),
                        ),
                      ],
                    );
                  }),

                const SizedBox(height: 24),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      Text(
                        'Selection Line Resume Interval: ${style.selectionAutoResumeDuration.inMilliseconds.toStringAsFixed(0)}ms',
                      ),
                      SizedBox(width: 30),
                      DropdownButton<SelectionAutoResumeMode>(
                        value: style.selectionAutoResumeMode,
                        items: const [
                          DropdownMenuItem(
                            value: SelectionAutoResumeMode.selecting,
                            child: Text('Selecting'),
                          ),
                          DropdownMenuItem(
                            value: SelectionAutoResumeMode.afterSelecting,
                            child: Text('After Stopping Selection'),
                          ),
                          DropdownMenuItem(
                            value: SelectionAutoResumeMode.neverResume,
                            child: Text('No Resume'),
                          ),
                        ],
                        onChanged: (value) {
                          style = style.copyWith(selectLineResumeMode: value);
                        },
                      ),
                    ],
                  ),
                ),
                Slider(
                  value: style.selectionAutoResumeDuration.inMilliseconds
                      .toDouble(),
                  min: 0,
                  max: 500,
                  onChanged: (value) {
                    style = style.copyWith(
                      selectLineResumeDuration: Duration(
                        milliseconds: value.toInt(),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 24),
                Text(
                  'Play Line Resume Interval: ${style.activeAutoResumeDuration.inMilliseconds.toStringAsFixed(0)}ms',
                ),
                Slider(
                  value: style.activeAutoResumeDuration.inMilliseconds
                      .toDouble(),
                  min: 500,
                  max: 5000,
                  divisions: 100,
                  onChanged: (value) {
                    style = style.copyWith(
                      activeLineResumeDuration: Duration(
                        milliseconds: value.toInt(),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
