import 'package:flutter/material.dart';
import 'package:flutter_lyric/flutter_lyric.dart';
import 'edit_preset.dart';

/// Several instances deliberately share the application's one controller.
class ShowLyric extends StatefulWidget {
  const ShowLyric({
    super.key,
    required this.controller,
    required this.initialPreset,
    this.presets = const {},
    this.onLineTap,
  });
  final LyricController controller;
  final LyricPreset initialPreset;
  final Map<String, LyricPreset> presets;
  final ValueChanged<LyricLineDetails>? onLineTap;
  @override
  State<ShowLyric> createState() => _ShowLyricState();
}

class _ShowLyricState extends State<ShowLyric> {
  late final ValueNotifier<LyricPreset> _preset = ValueNotifier(
    widget.initialPreset,
  );
  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(border: Border.all(color: Colors.white10)),
    child: ValueListenableBuilder<LyricPreset>(
      valueListenable: _preset,
      builder: (context, preset, _) => Stack(
        fit: StackFit.expand,
        children: [
          LyricView(
            controller: widget.controller,
            preset: preset,
            onLineTap: widget.onLineTap,
          ),
          Positioned(
            right: 12,
            top: 12,
            child: IconButton(
              tooltip: 'Customize preset',
              icon: const Icon(Icons.settings, color: Colors.white),
              onPressed: () => showDialog<void>(
                context: context,
                builder: (context) => ValueListenableBuilder<LyricPreset>(
                  valueListenable: _preset,
                  builder: (context, value, _) => EditPreset(
                    preset: value,
                    presets: {
                      'Centered': LyricPresets.centered,
                      'Leading': LyricPresets.leading,
                      'Single line': LyricPresets.singleLine,
                      ...widget.presets,
                    },
                    onChanged: (value) => _preset.value = value,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
  @override
  void dispose() {
    _preset.dispose();
    super.dispose();
  }
}

Widget selectionBackground(
  BuildContext context,
  LyricSelectionDetails details,
) => Stack(
  children: [
    Positioned.fromRect(
      rect: details.lineRect,
      child: DecoratedBox(
        decoration: BoxDecoration(color: Colors.white.withValues(alpha: .08)),
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
      left: 6,
      right: 6,
      top: details.anchorY - 20,
      height: 40,
      child: Row(
        children: [
          Text(
            '${details.line.seekPosition.inMinutes}:${(details.line.seekPosition.inSeconds % 60).toString().padLeft(2, '0')}',
            style: const TextStyle(color: Colors.white70, fontSize: 10),
          ),
          const Spacer(),
          IconButton(
            tooltip: 'Play selected line',
            onPressed: details.onTap,
            icon: const Icon(Icons.play_arrow, color: Colors.white),
          ),
          IconButton(
            tooltip: 'Follow playback',
            onPressed: details.resumeFollow,
            icon: const Icon(Icons.my_location, color: Colors.white70),
          ),
        ],
      ),
    ),
  ],
);
