import 'package:flutter/material.dart';
import 'package:flutter_lyric/flutter_lyric.dart';

class EditPreset extends StatelessWidget {
  const EditPreset({
    super.key,
    required this.preset,
    required this.presets,
    required this.onChanged,
  });
  final LyricPreset preset;
  final Map<String, LyricPreset> presets;
  final ValueChanged<LyricPreset> onChanged;

  @override
  Widget build(BuildContext context) {
    Widget slider(
      String label,
      double value,
      double max,
      ValueChanged<double> change, {
      double min = 0,
    }) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('$label: ${value.toStringAsFixed(1)}'),
        Slider(
          value: value.clamp(min, max),
          min: min,
          max: max,
          onChanged: change,
        ),
      ],
    );
    return AlertDialog(
      title: const Text('Lyric preset'),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Wrap(
                spacing: 8,
                children: presets.entries
                    .map(
                      (entry) => OutlinedButton(
                        onPressed: () => onChanged(entry.value),
                        child: Text(entry.key),
                      ),
                    )
                    .toList(),
              ),
              slider(
                'Text size',
                preset.textStyle.fontSize ?? 14,
                40,
                (v) => onChanged(
                  preset.copyWith(
                    textStyle: preset.textStyle.copyWith(fontSize: v),
                  ),
                ),
                min: 8,
              ),
              slider(
                'Active text size',
                preset.activeTextStyle.fontSize ?? 18,
                48,
                (v) => onChanged(
                  preset.copyWith(
                    activeTextStyle: preset.activeTextStyle.copyWith(
                      fontSize: v,
                    ),
                  ),
                ),
                min: 8,
              ),
              slider(
                'Translation size',
                preset.translationTextStyle.fontSize ?? 12,
                40,
                (v) => onChanged(
                  preset.copyWith(
                    translationTextStyle: preset.translationTextStyle.copyWith(
                      fontSize: v,
                    ),
                  ),
                ),
                min: 8,
              ),
              slider(
                'Active translation size',
                preset.activeTranslationTextStyle.fontSize ??
                    preset.translationTextStyle.fontSize ??
                    12,
                40,
                (v) => onChanged(
                  preset.copyWith(
                    activeTranslationTextStyle: preset
                        .activeTranslationTextStyle
                        .copyWith(fontSize: v),
                  ),
                ),
                min: 8,
              ),
              slider(
                'Line spacing',
                preset.lineSpacing,
                80,
                (v) => onChanged(preset.copyWith(lineSpacing: v)),
              ),
              slider(
                'Translation spacing',
                preset.translationSpacing,
                30,
                (v) => onChanged(preset.copyWith(translationSpacing: v)),
              ),
              slider(
                'Active anchor (fraction)',
                preset.activeAnchor.isFraction
                    ? preset.activeAnchor.position
                    : .5,
                1,
                (v) => onChanged(
                  preset.copyWith(
                    activeAnchor: LyricAnchor.fraction(
                      v,
                      target: preset.activeAnchor.target,
                    ),
                  ),
                ),
              ),
              slider(
                'Selection anchor (fraction)',
                preset.selectionAnchor.isFraction
                    ? preset.selectionAnchor.position
                    : .5,
                1,
                (v) => onChanged(
                  preset.copyWith(
                    selectionAnchor: LyricAnchor.fraction(
                      v,
                      target: preset.selectionAnchor.target,
                    ),
                  ),
                ),
              ),
              DropdownButton<LyricAnchorTarget>(
                value: preset.activeAnchor.target,
                items: LyricAnchorTarget.values
                    .map((v) => DropdownMenuItem(value: v, child: Text(v.name)))
                    .toList(),
                onChanged: (v) {
                  if (v != null) {
                    onChanged(
                      preset.copyWith(
                        activeAnchor: LyricAnchor.fraction(
                          preset.activeAnchor.isFraction
                              ? preset.activeAnchor.position
                              : .5,
                          target: v,
                        ),
                      ),
                    );
                  }
                },
              ),
              DropdownButton<LyricContentAlignment>(
                value: preset.contentAlignment,
                items: LyricContentAlignment.values
                    .map((v) => DropdownMenuItem(value: v, child: Text(v.name)))
                    .toList(),
                onChanged: (v) {
                  if (v != null) {
                    onChanged(preset.copyWith(contentAlignment: v));
                  }
                },
              ),
              DropdownButton<TextAlign>(
                value: preset.textAlign,
                items: TextAlign.values
                    .map(
                      (v) => DropdownMenuItem(
                        value: v,
                        child: Text('Text: ${v.name}'),
                      ),
                    )
                    .toList(),
                onChanged: (v) {
                  if (v != null) onChanged(preset.copyWith(textAlign: v));
                },
              ),
              SwitchListTile(
                title: const Text('Single active line'),
                value: preset.displayMode == LyricDisplayMode.activeLine,
                onChanged: (v) => onChanged(
                  preset.copyWith(
                    displayMode: v
                        ? LyricDisplayMode.activeLine
                        : LyricDisplayMode.scrollable,
                  ),
                ),
              ),
              SwitchListTile(
                title: const Text('Interactive'),
                value: preset.interactive,
                onChanged: (v) => onChanged(preset.copyWith(interactive: v)),
              ),
              DropdownButton<LyricSelectionSnapMode>(
                value: preset.selectionSnapMode,
                items: LyricSelectionSnapMode.values
                    .map(
                      (v) => DropdownMenuItem(
                        value: v,
                        child: Text('Snap: ${v.name}'),
                      ),
                    )
                    .toList(),
                onChanged: (v) {
                  if (v != null) {
                    onChanged(preset.copyWith(selectionSnapMode: v));
                  }
                },
              ),
              slider(
                'Snap delay (ms)',
                preset.selectionSnapDelay.inMilliseconds.toDouble(),
                2000,
                (v) => onChanged(
                  preset.copyWith(
                    selectionSnapDelay: Duration(milliseconds: v.round()),
                  ),
                ),
              ),
              SwitchListTile(
                title: const Text('Auto resume'),
                value: preset.resumeDelay != null,
                onChanged: (v) => onChanged(
                  v
                      ? preset.copyWith(resumeDelay: const Duration(seconds: 3))
                      : preset.copyWith(clearResumeDelay: true),
                ),
              ),
              if (preset.resumeDelay != null)
                slider(
                  'Resume delay (ms)',
                  preset.resumeDelay!.inMilliseconds.toDouble(),
                  10000,
                  (v) => onChanged(
                    preset.copyWith(
                      resumeDelay: Duration(milliseconds: v.round()),
                    ),
                  ),
                ),
              SwitchListTile(
                title: const Text('Resume after tap'),
                value: preset.resumeOnTap,
                onChanged: (v) => onChanged(preset.copyWith(resumeOnTap: v)),
              ),
              SwitchListTile(
                title: const Text('Line transitions'),
                value: preset.lineTransition.enabled,
                onChanged: (v) => onChanged(
                  preset.copyWith(
                    lineTransition: v
                        ? const LyricLineTransition()
                        : const LyricLineTransition.none(),
                  ),
                ),
              ),
              SwitchListTile(
                title: const Text('Edge fade'),
                value: preset.edgeFade.enabled,
                onChanged: (v) => onChanged(
                  preset.copyWith(
                    edgeFade: v
                        ? const LyricEdgeFade.pixels(top: 32, bottom: 32)
                        : const LyricEdgeFade.none(),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Done'),
        ),
      ],
    );
  }
}
