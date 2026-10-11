// @dart=3.8

import 'package:flutter/material.dart';
import 'demo_presets.dart';
import 'studio_state.dart';
import 'studio_theme.dart';

class PresetGallery extends StatefulWidget {
  const PresetGallery({
    super.key,
    required this.state,
    this.horizontal = false,
  });
  final StudioState state;
  final bool horizontal;
  @override
  State<PresetGallery> createState() => _PresetGalleryState();
}

class _PresetGalleryState extends State<PresetGallery> {
  late bool _lab = widget.state.selected.lab;
  @override
  Widget build(BuildContext context) {
    final entries = widget.state.catalog.where((e) => e.lab == _lab).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(widget.horizontal ? 20 : 8, 0, 8, 12),
          child: Row(
            children: [
              if (!widget.horizontal) ...[
                const Icon(
                  Icons.grid_view_rounded,
                  size: 16,
                  color: studioMuted,
                ),
                const Spacer(),
              ],
              _filter('风格', false),
              const SizedBox(width: 4),
              _filter('实验室 · 7', true),
              if (widget.horizontal) const Spacer(),
              if (widget.horizontal)
                const Padding(
                  padding: EdgeInsets.only(right: 12),
                  child: Icon(
                    Icons.swipe_rounded,
                    size: 16,
                    color: studioMuted,
                  ),
                ),
            ],
          ),
        ),
        Expanded(
          child: ListView.separated(
            key: PageStorageKey('gallery-${widget.horizontal}-$_lab'),
            scrollDirection: widget.horizontal
                ? Axis.horizontal
                : Axis.vertical,
            padding: EdgeInsets.symmetric(
              horizontal: widget.horizontal ? 20 : 4,
              vertical: 2,
            ),
            itemCount: entries.length,
            separatorBuilder: (_, _) => SizedBox(
              width: widget.horizontal ? 10 : 0,
              height: widget.horizontal ? 0 : 10,
            ),
            itemBuilder: (context, index) => _PresetCard(
              item: entries[index],
              index: index,
              compact: widget.horizontal,
              selected: widget.state.selected.id == entries[index].id,
              modified: widget.state.isModified(entries[index]),
              onTap: () => widget.state.select(entries[index]),
            ),
          ),
        ),
        if (!widget.horizontal)
          const Padding(
            padding: EdgeInsets.fromLTRB(8, 16, 8, 0),
            child: Text(
              '每一种风格，都可以成为你的版本。\n修改在本次会话中独立保留。',
              style: TextStyle(fontSize: 11, height: 1.7, color: studioMuted),
            ),
          ),
      ],
    );
  }

  Widget _filter(String name, bool lab) => Semantics(
    selected: _lab == lab,
    child: InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () => setState(() => _lab = lab),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
        decoration: BoxDecoration(
          color: _lab == lab ? studioInk : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          name,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: _lab == lab ? Colors.white : studioMuted,
          ),
        ),
      ),
    ),
  );
}

class _PresetCard extends StatelessWidget {
  const _PresetCard({
    required this.item,
    required this.index,
    required this.compact,
    required this.selected,
    required this.modified,
    required this.onTap,
  });
  final DemoPreset item;
  final int index;
  final bool compact;
  final bool selected;
  final bool modified;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    selected: selected,
    label: '${item.name}预设${modified ? '，已修改' : ''}',
    child: SizedBox(
      width: compact ? 158 : null,
      child: Material(
        color: selected ? Colors.white : const Color(0xFFEEEFE8),
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          key: ValueKey('preset-${item.id}'),
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: EdgeInsets.all(compact ? 10 : 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: selected ? studioAccent : Colors.transparent,
                width: 1.5,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (!compact)
                  Container(
                    height: 68,
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    alignment: item.preset.textAlign == TextAlign.center
                        ? Alignment.center
                        : item.preset.textAlign == TextAlign.end
                        ? Alignment.centerRight
                        : Alignment.centerLeft,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(9),
                      gradient: LinearGradient(colors: item.background),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment:
                          item.preset.textAlign == TextAlign.center
                          ? CrossAxisAlignment.center
                          : item.preset.textAlign == TextAlign.end
                          ? CrossAxisAlignment.end
                          : CrossAxisAlignment.start,
                      children: [
                        if (item.id != 'cinema')
                          const Text(
                            'whatever you wanna be',
                            maxLines: 1,
                            overflow: TextOverflow.fade,
                            style: TextStyle(
                              fontSize: 8,
                              color: Colors.white30,
                            ),
                          ),
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 3),
                          child: Text(
                            'Be what you wanna be',
                            maxLines: 1,
                            overflow: TextOverflow.fade,
                            style: TextStyle(
                              fontSize: item.id == 'editorial' ? 13 : 11,
                              color: item.accent,
                              fontWeight: FontWeight.w600,
                              fontFamily: item.id == 'terminal'
                                  ? 'monospace'
                                  : null,
                            ),
                          ),
                        ),
                        if (item.id != 'cinema')
                          const Text(
                            '成为你想成为的人',
                            maxLines: 1,
                            overflow: TextOverflow.fade,
                            style: TextStyle(
                              fontSize: 7,
                              color: Colors.white30,
                            ),
                          ),
                      ],
                    ),
                  ),
                Row(
                  children: [
                    if (compact) ...[
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: item.background.first,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 7),
                    ],
                    Expanded(
                      child: Text(
                        item.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    if (modified)
                      const Padding(
                        padding: EdgeInsets.only(right: 4),
                        child: Icon(Icons.circle, size: 5, color: studioAccent),
                      ),
                    Icon(
                      selected
                          ? Icons.check_circle_rounded
                          : Icons.north_east_rounded,
                      size: 15,
                      color: selected ? studioAccent : studioMuted,
                    ),
                  ],
                ),
                const SizedBox(height: 5),
                Text(
                  '${(index + 1).toString().padLeft(2, '0')} / ${item.tag}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 9,
                    letterSpacing: 1,
                    color: studioMuted,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
