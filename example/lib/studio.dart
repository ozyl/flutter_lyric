import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_lyric/flutter_lyric.dart';
import 'edit_preset.dart';
import 'preset_gallery.dart';
import 'show_lyric.dart';
import 'studio_state.dart';
import 'studio_theme.dart';

/// Responsive shell, kept independent of audio plugins for layout testing.
class LyricStudio extends StatefulWidget {
  const LyricStudio({
    super.key,
    required this.controller,
    required this.playback,
    this.onLineTap,
    this.onTogglePlayback,
    this.state,
  });
  final LyricController controller;
  final Widget playback;
  final ValueChanged<LyricLineDetails>? onLineTap;
  final VoidCallback? onTogglePlayback;
  final StudioState? state;
  @override
  State<LyricStudio> createState() => _LyricStudioState();
}

class _LyricStudioState extends State<LyricStudio> {
  late final StudioState _state = widget.state ?? StudioState();
  bool _compare = false;
  bool _guide = false;
  bool _focus = false;
  bool _sheetOpen = false;
  double _sheetExtent = .52;

  @override
  void dispose() {
    if (widget.state == null) _state.dispose();
    super.dispose();
  }

  Future<void> _openEditor() async {
    setState(() {
      _sheetOpen = true;
      _sheetExtent = .52;
      _compare = false;
    });
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: studioPaper,
      barrierColor: Colors.black.withValues(alpha: .12),
      constraints: const BoxConstraints(maxWidth: 540),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) =>
          NotificationListener<DraggableScrollableNotification>(
            onNotification: (notification) {
              if (mounted && _sheetExtent != notification.extent) {
                setState(() => _sheetExtent = notification.extent);
              }
              return false;
            },
            child: DraggableScrollableSheet(
              initialChildSize: .52,
              minChildSize: .38,
              maxChildSize: .9,
              expand: false,
              builder: (context, scrollController) => SafeArea(
                top: false,
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(
                        left: 20,
                        right: 8,
                        top: 6,
                      ),
                      child: Row(
                        children: [
                          const Text(
                            '向上拖动，探索更多参数',
                            style: TextStyle(fontSize: 10, color: studioMuted),
                          ),
                          const Spacer(),
                          IconButton(
                            tooltip: '关闭调节面板',
                            onPressed: () => Navigator.pop(context),
                            icon: const Icon(Icons.keyboard_arrow_down_rounded),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: ListenableBuilder(
                        listenable: _state,
                        builder: (_, _) => EditPreset(
                          state: _state,
                          scrollController: scrollController,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
    );
    if (mounted) setState(() => _sheetOpen = false);
  }

  @override
  Widget build(BuildContext context) => CallbackShortcuts(
    bindings: {
      const SingleActivator(LogicalKeyboardKey.space): () =>
          widget.onTogglePlayback?.call(),
      const SingleActivator(LogicalKeyboardKey.keyZ, meta: true): _state.undo,
      const SingleActivator(LogicalKeyboardKey.keyZ, control: true):
          _state.undo,
      const SingleActivator(LogicalKeyboardKey.keyZ, meta: true, shift: true):
          _state.redo,
      const SingleActivator(
        LogicalKeyboardKey.keyZ,
        control: true,
        shift: true,
      ): _state.redo,
      const SingleActivator(LogicalKeyboardKey.escape): () {
        if (_focus) setState(() => _focus = false);
      },
    },
    child: Focus(
      autofocus: true,
      child: Scaffold(
        body: SafeArea(
          child: ListenableBuilder(
            listenable: _state,
            builder: (context, _) => LayoutBuilder(
              builder: (context, constraints) {
                if (_sheetOpen) {
                  return Align(
                    alignment: Alignment.topCenter,
                    child: SizedBox(
                      height: (constraints.maxHeight * (1 - _sheetExtent))
                          .clamp(260.0, double.infinity),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: _stages(constraints.maxWidth),
                      ),
                    ),
                  );
                }
                // Preserve useful preview space on landscape phones and split windows.
                final desktop =
                    constraints.maxWidth >= 1180 &&
                    constraints.maxHeight >= 620;
                final rail =
                    constraints.maxWidth >= 860 && constraints.maxHeight >= 580;
                final compactHeight = constraints.maxHeight < 740;
                final content = Column(
                  children: [
                    _header(constraints.maxWidth < 600),
                    if (!_focus && !compactHeight) _intro(rail),
                    if (!_focus && !rail)
                      SizedBox(
                        height: compactHeight ? 112 : 134,
                        child: PresetGallery(state: _state, horizontal: true),
                      ),
                    Expanded(
                      child: Padding(
                        padding: EdgeInsets.fromLTRB(
                          rail ? 28 : 16,
                          12,
                          rail ? 28 : 16,
                          16,
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (!_focus && rail) ...[
                              SizedBox(
                                width: 224,
                                child: PresetGallery(state: _state),
                              ),
                              const SizedBox(width: 22),
                            ],
                            Expanded(
                              child: Column(
                                children: [
                                  _stageToolbar(
                                    desktop && !_focus,
                                    constraints.maxWidth,
                                  ),
                                  const SizedBox(height: 10),
                                  Expanded(
                                    child: _stages(constraints.maxWidth),
                                  ),
                                  const SizedBox(height: 12),
                                  widget.playback,
                                ],
                              ),
                            ),
                            if (!_focus && desktop) ...[
                              const SizedBox(width: 22),
                              Container(
                                width: 318,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFAFAF6),
                                  border: Border.all(color: studioLine),
                                  borderRadius: BorderRadius.circular(22),
                                ),
                                clipBehavior: Clip.antiAlias,
                                child: EditPreset(state: _state),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ],
                );
                // Short windows remain usable by scrolling, without shrinking the
                // lyric viewport or clipping transport/editor controls.
                return constraints.maxHeight < 660
                    ? SingleChildScrollView(
                        child: SizedBox(height: 700, child: content),
                      )
                    : content;
              },
            ),
          ),
        ),
      ),
    ),
  );

  Widget _header(bool mobile) => Container(
    padding: EdgeInsets.symmetric(
      horizontal: mobile ? 20 : 32,
      vertical: mobile ? 14 : 19,
    ),
    decoration: const BoxDecoration(
      border: Border(bottom: BorderSide(color: studioLine)),
    ),
    child: Row(
      children: [
        Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            color: studioInk,
            borderRadius: BorderRadius.circular(9),
          ),
          child: const Icon(
            Icons.graphic_eq_rounded,
            size: 20,
            color: Color(0xFFD5EDAD),
          ),
        ),
        const SizedBox(width: 10),
        const Text(
          'lyric',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            letterSpacing: -1,
          ),
        ),
        const SizedBox(width: 8),
        const StudioLabel('STUDIO'),
        const Spacer(),
        if (!mobile) ...[
          const StudioLabel('FLUTTER LYRIC / PLAYGROUND'),
          const SizedBox(width: 28),
        ],
        if (!mobile) ...[
          Container(
            width: 6,
            height: 6,
            decoration: const BoxDecoration(
              color: studioAccent,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          const Text(
            '配置即体验',
            style: TextStyle(fontSize: 10, color: studioMuted),
          ),
        ],
      ],
    ),
  );

  Widget _intro(bool wide) => Padding(
    padding: EdgeInsets.fromLTRB(
      wide ? 32 : 20,
      wide ? 22 : 16,
      wide ? 32 : 20,
      wide ? 22 : 14,
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '听见文字的形状。',
                style: TextStyle(
                  fontSize: wide ? 30 : 23,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -1,
                ),
              ),
              const SizedBox(height: 7),
              Text(
                wide ? '选一种气质，调一点细节。让歌词成为音乐的一部分。' : '选一种气质，让歌词成为音乐的一部分。',
                style: const TextStyle(fontSize: 11, color: studioMuted),
              ),
            ],
          ),
        ),
        if (wide)
          const Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              StudioLabel('08 STYLES + 07 EXPERIMENTS'),
              SizedBox(height: 7),
              Text(
                '空格 播放 / 暂停   ·   ⌘ / Ctrl Z 撤销',
                style: TextStyle(fontSize: 10, color: studioMuted),
              ),
            ],
          ),
      ],
    ),
  );

  Widget _stageToolbar(bool hasEditor, double width) => SizedBox(
    height: 34,
    child: Row(
      children: [
        if (width >= 600)
          Expanded(
            child: Text(
              _state.selected.caption,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 11, color: studioMuted),
            ),
          )
        else
          const Spacer(),
        _tool(
          '原版对照',
          Icons.vertical_split_outlined,
          _compare,
          () => setState(() => _compare = !_compare),
        ),
        _tool(
          '锚点辅助线',
          Icons.horizontal_rule_rounded,
          _guide,
          () => setState(() => _guide = !_guide),
        ),
        _tool(
          _focus ? '退出专注' : '专注模式',
          _focus ? Icons.fullscreen_exit_rounded : Icons.fullscreen_rounded,
          _focus,
          () => setState(() => _focus = !_focus),
        ),
        if (!hasEditor) ...[
          const SizedBox(width: 8),
          FilledButton.tonalIcon(
            onPressed: _openEditor,
            icon: const Icon(Icons.tune_rounded, size: 16),
            label: const Text('调节', style: TextStyle(fontSize: 12)),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              minimumSize: const Size(0, 34),
            ),
          ),
        ],
      ],
    ),
  );

  Widget _tool(
    String label,
    IconData icon,
    bool selected,
    VoidCallback action,
  ) => IconButton(
    tooltip: label,
    isSelected: selected,
    onPressed: action,
    style: IconButton.styleFrom(
      backgroundColor: selected ? const Color(0xFFE4EBD9) : Colors.transparent,
      padding: const EdgeInsets.all(7),
      minimumSize: const Size(34, 34),
    ),
    icon: Icon(icon, size: 18),
  );

  Widget _stages(double width) => LayoutBuilder(
    builder: (context, constraints) {
      Widget stage(bool original) => ShowLyric(
        key: ValueKey(original ? 'original' : 'draft'),
        controller: widget.controller,
        demo: _state.selected,
        preset: original ? _state.selected.preset : _state.preset,
        onLineTap: widget.onLineTap,
        original: original,
        showGuide: _guide,
      );
      if (!_compare) return stage(false);
      // A/B uses the full mobile stage; desktop can show both simultaneously.
      if (constraints.maxWidth < 720) {
        return Stack(
          children: [
            Positioned.fill(child: stage(true)),
            Positioned(
              top: 18,
              right: 48,
              child: ActionChip(
                label: const Text('返回我的版本', style: TextStyle(fontSize: 10)),
                onPressed: () => setState(() => _compare = false),
              ),
            ),
          ],
        );
      }
      return Row(
        children: [
          Expanded(child: stage(false)),
          const SizedBox(width: 12),
          Expanded(child: stage(true)),
        ],
      );
    },
  );
}
