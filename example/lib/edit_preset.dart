import 'package:flutter/material.dart';
import 'package:flutter_lyric/flutter_lyric.dart';
import 'studio_state.dart';
import 'scroll_tuning.dart';
import 'studio_theme.dart';

const _curves = <String, Curve>{
  '平滑减速': Curves.easeOutCubic,
  '匀速': Curves.linear,
  '渐入': Curves.easeInCubic,
  '渐入渐出': Curves.easeInOutCubic,
  '回弹': Curves.easeOutBack,
  '弹跳': Curves.bounceOut,
  '弹簧': Curves.elasticOut,
};

class EditPreset extends StatefulWidget {
  const EditPreset({super.key, required this.state, this.scrollController});
  final StudioState state;
  final ScrollController? scrollController;
  @override
  State<EditPreset> createState() => _EditPresetState();
}

class _EditPresetState extends State<EditPreset> {
  int _tab = 0;
  LyricScrollAnimation? _scrollStart;
  LyricPreset get p => widget.state.preset;
  void update(LyricPreset value) => widget.state.update(value);

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 18, 12, 12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const StudioLabel('MAKE IT YOURS'),
                  const SizedBox(height: 6),
                  Text(
                    '调节 · ${widget.state.selected.name}',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: '撤销修改',
              onPressed: widget.state.canUndo ? widget.state.undo : null,
              icon: const Icon(Icons.undo_rounded, size: 18),
            ),
            IconButton(
              tooltip: '重做修改',
              onPressed: widget.state.canRedo ? widget.state.redo : null,
              icon: const Icon(Icons.redo_rounded, size: 18),
            ),
          ],
        ),
      ),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: const Color(0xFFECEEE6),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              for (final (i, label) in ['文字', '布局', '动效', '交互'].indexed)
                Expanded(
                  child: Semantics(
                    selected: _tab == i,
                    child: InkWell(
                      key: ValueKey('inspector-tab-$i'),
                      borderRadius: BorderRadius.circular(9),
                      onTap: () => setState(() => _tab = i),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 9),
                        decoration: BoxDecoration(
                          color: _tab == i ? Colors.white : Colors.transparent,
                          borderRadius: BorderRadius.circular(9),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          label,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: _tab == i
                                ? FontWeight.w700
                                : FontWeight.w400,
                            color: _tab == i ? studioInk : studioMuted,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
      const SizedBox(height: 6),
      Expanded(
        child: ListView(
          key: PageStorageKey('inspector-$_tab'),
          controller: widget.scrollController,
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          children: switch (_tab) {
            0 => _typography(),
            1 => _layout(),
            2 => _motion(),
            _ => _interaction(),
          },
        ),
      ),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: studioLine)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                widget.state.isModified(widget.state.selected)
                    ? '● 已修改 · 本次会话保留'
                    : '默认配置 · 即调即见',
                style: const TextStyle(fontSize: 10, color: studioMuted),
              ),
            ),
            TextButton(
              onPressed: widget.state.isModified(widget.state.selected)
                  ? widget.state.reset
                  : null,
              child: const Text('重置', style: TextStyle(fontSize: 12)),
            ),
          ],
        ),
      ),
    ],
  );

  List<Widget> _typography() => [
    _section('01', '字的表情', '主句与译文分别调节，让层级更清晰。'),
    _slider(
      '正文大小',
      p.textStyle.fontSize ?? 14,
      10,
      48,
      (v) => update(p.copyWith(textStyle: p.textStyle.copyWith(fontSize: v))),
      unit: 'px',
    ),
    _slider(
      '当前句大小',
      p.activeTextStyle.fontSize ?? 18,
      10,
      60,
      (v) => update(
        p.copyWith(activeTextStyle: p.activeTextStyle.copyWith(fontSize: v)),
      ),
      unit: 'px',
    ),
    _choice(
      '当前句字重',
      p.activeTextStyle.fontWeight ?? FontWeight.normal,
      {
        FontWeight.w400: '轻盈',
        FontWeight.w500: '常规',
        FontWeight.w600: '适中',
        FontWeight.w700: '加粗',
        FontWeight.w800: '醒目',
      },
      (v) => update(
        p.copyWith(activeTextStyle: p.activeTextStyle.copyWith(fontWeight: v)),
      ),
    ),
    _slider(
      '正文透明度',
      (p.textStyle.color ?? Colors.white).a,
      0,
      1,
      (v) => update(
        p.copyWith(
          textStyle: p.textStyle.copyWith(
            color: (p.textStyle.color ?? Colors.white).withValues(alpha: v),
          ),
        ),
      ),
      percent: true,
    ),
    _slider(
      '当前句底色透明度',
      (p.activeTextStyle.color ?? Colors.white).a,
      0,
      1,
      (v) => update(
        p.copyWith(
          activeTextStyle: p.activeTextStyle.copyWith(
            color: (p.activeTextStyle.color ?? Colors.white).withValues(
              alpha: v,
            ),
          ),
        ),
      ),
      percent: true,
    ),
    _palette(
      '当前句底色',
      p.activeTextStyle.color ?? Colors.white,
      (v) => update(
        p.copyWith(
          activeTextStyle: p.activeTextStyle.copyWith(
            color: v.withValues(
              alpha: (p.activeTextStyle.color ?? Colors.white).a,
            ),
          ),
        ),
      ),
    ),
    _section('02', '另一种语言', '译文始终跟随主句，也有自己的呼吸。'),
    _slider(
      '译文大小',
      p.translationTextStyle.fontSize ?? 12,
      8,
      32,
      (v) => update(
        p.copyWith(
          translationTextStyle: p.translationTextStyle.copyWith(fontSize: v),
        ),
      ),
      unit: 'px',
    ),
    _slider(
      '当前译文大小',
      p.activeTranslationTextStyle.fontSize ??
          p.translationTextStyle.fontSize ??
          12,
      8,
      36,
      (v) => update(
        p.copyWith(
          activeTranslationTextStyle: p.activeTranslationTextStyle.copyWith(
            fontSize: v,
          ),
        ),
      ),
      unit: 'px',
    ),
    _slider(
      '译文间距',
      p.translationSpacing,
      0,
      32,
      (v) => update(p.copyWith(translationSpacing: v)),
      unit: 'px',
    ),
  ];

  List<Widget> _layout() => [
    _section('01', '舞台构图', '从多行叙事，到只聚焦此刻。'),
    _choice('显示方式', p.displayMode, const {
      LyricDisplayMode.scrollable: '多行',
      LyricDisplayMode.activeLine: '单行',
    }, (v) => update(p.copyWith(displayMode: v))),
    _choice('文字对齐', p.textAlign, const {
      TextAlign.start: '靠左',
      TextAlign.center: '居中',
      TextAlign.end: '靠右',
    }, (v) => update(p.copyWith(textAlign: v))),
    _choice('内容对齐', p.contentAlignment, const {
      LyricContentAlignment.start: '靠左',
      LyricContentAlignment.center: '居中',
      LyricContentAlignment.end: '靠右',
    }, (v) => update(p.copyWith(contentAlignment: v))),
    _slider(
      '行间留白',
      p.lineSpacing,
      0,
      80,
      (v) => update(p.copyWith(lineSpacing: v)),
      unit: 'px',
    ),
    _slider(
      '水平边距',
      p.padding.resolve(TextDirection.ltr).left,
      0,
      80,
      (v) => update(
        p.copyWith(
          padding: EdgeInsets.symmetric(
            horizontal: v,
            vertical: p.padding.resolve(TextDirection.ltr).top,
          ),
        ),
      ),
      unit: 'px',
    ),
    _section('02', '视觉锚点', '配合舞台上方的辅助线，找到视觉重心。'),
    ..._anchor(
      '当前句',
      p.activeAnchor,
      (v) => update(p.copyWith(activeAnchor: v)),
    ),
    ..._anchor(
      '选择句',
      p.selectionAnchor,
      (v) => update(p.copyWith(selectionAnchor: v)),
    ),
  ];

  List<Widget> _anchor(
    String label,
    LyricAnchor anchor,
    ValueChanged<LyricAnchor> change,
  ) => [
    _choice(
      '$label锚点单位',
      anchor.isFraction,
      const {true: '比例', false: '像素'},
      (fraction) => change(
        fraction
            ? LyricAnchor.fraction(.5, target: anchor.target)
            : LyricAnchor.pixels(160, target: anchor.target),
      ),
    ),
    _slider(
      '$label位置',
      anchor.position,
      0,
      anchor.isFraction ? 1 : 600,
      (v) => change(
        anchor.isFraction
            ? LyricAnchor.fraction(v, target: anchor.target)
            : LyricAnchor.pixels(v, target: anchor.target),
      ),
      percent: anchor.isFraction,
      unit: anchor.isFraction ? '' : 'px',
    ),
    _choice(
      '$label对齐基准',
      anchor.target,
      const {
        LyricAnchorTarget.mainText: '主句',
        LyricAnchorTarget.translationText: '译文',
        LyricAnchorTarget.lineCenter: '整行',
      },
      (v) => change(
        anchor.isFraction
            ? LyricAnchor.fraction(anchor.position, target: v)
            : LyricAnchor.pixels(anchor.position, target: v),
      ),
    ),
  ];

  List<Widget> _motion() {
    final scroll = p.scrollAnimation.resolve(100);
    final curveName = _curves.entries
        .where((e) => e.value == scroll.curve)
        .firstOrNull
        ?.key;
    return [
      _section('01', '逐字点亮', '高亮独立于底字透明度，保留清晰色彩。'),
      _choice(
        '高亮方式',
        !p.highlight.enabled
            ? 0
            : p.highlight.gradient == null
            ? 1
            : 2,
        const {0: '关闭', 1: '纯色', 2: '渐变'},
        (v) => update(
          p.copyWith(
            highlight: switch (v) {
              0 => const LyricHighlight.none(),
              1 => LyricHighlight.solid(
                widget.state.selected.accent,
                tailFadeWidth: 28,
              ),
              _ => LyricHighlight.gradient(
                LinearGradient(
                  colors: [
                    widget.state.selected.accent,
                    const Color(0xFF90E9EE),
                  ],
                ),
                tailFadeWidth: 28,
              ),
            },
          ),
        ),
      ),
      if (p.highlight.enabled) ...[
        _palette(
          p.highlight.gradient == null ? '高亮颜色' : '渐变起点',
          p.highlight.color ?? p.highlight.gradient!.colors.first,
          (v) => _highlightColor(v, false),
        ),
        if (p.highlight.gradient != null)
          _palette(
            '渐变终点',
            p.highlight.gradient!.colors.last,
            (v) => _highlightColor(v, true),
          ),
        _slider(
          '高亮尾部柔化',
          p.highlight.tailFadeWidth,
          0,
          100,
          (v) => update(
            p.copyWith(
              highlight: p.highlight.gradient != null
                  ? LyricHighlight.gradient(
                      p.highlight.gradient!,
                      tailFadeWidth: v,
                    )
                  : LyricHighlight.solid(p.highlight.color!, tailFadeWidth: v),
            ),
          ),
          unit: 'px',
        ),
      ],
      _section(
        '02',
        '滚动节奏',
        p.scrollAnimation.resolver != null
            ? '保留预设的距离时长计算；调整会按比例缩放。'
            : '调节过渡时间与曲线，塑造不同的节奏。',
      ),
      _slider(
        '滚动时长 · 100px',
        scroll.duration.inMilliseconds.toDouble(),
        0,
        3000,
        (v) => update(
          p.copyWith(
            scrollAnimation: tuneScroll(
              _scrollStart ?? p.scrollAnimation,
              milliseconds: v.round(),
            ),
          ),
        ),
        unit: 'ms',
      ),
      _choice(
        '滚动曲线',
        curveName ?? '自定义',
        {
          if (curveName == null) '自定义': '自定义',
          for (final name in _curves.keys) name: name,
        },
        (v) {
          if (_curves[v] != null) {
            update(
              p.copyWith(
                scrollAnimation: tuneScroll(
                  p.scrollAnimation,
                  curve: _curves[v],
                ),
              ),
            );
          }
        },
      ),
      _toggle(
        '文字渐变过渡',
        p.lineTransition.enabled,
        (v) => update(
          p.copyWith(
            lineTransition: v
                ? const LyricLineTransition()
                : const LyricLineTransition.none(),
          ),
        ),
      ),
      if (p.lineTransition.enabled) ...[
        _slider(
          '进入时长',
          p.lineTransition.enterDuration.inMilliseconds.toDouble(),
          0,
          1500,
          (v) => update(
            p.copyWith(
              lineTransition: LyricLineTransition(
                enterDuration: Duration(milliseconds: v.round()),
                exitDuration: p.lineTransition.exitDuration,
                enterCurve: p.lineTransition.enterCurve,
                exitCurve: p.lineTransition.exitCurve,
              ),
            ),
          ),
          unit: 'ms',
        ),
        _slider(
          '退出时长',
          p.lineTransition.exitDuration.inMilliseconds.toDouble(),
          0,
          1500,
          (v) => update(
            p.copyWith(
              lineTransition: LyricLineTransition(
                enterDuration: p.lineTransition.enterDuration,
                exitDuration: Duration(milliseconds: v.round()),
                enterCurve: p.lineTransition.enterCurve,
                exitCurve: p.lineTransition.exitCurve,
              ),
            ),
          ),
          unit: 'ms',
        ),
      ],
      _section('03', '边缘消隐', '让歌词自然地进入和离开舞台。'),
      _toggle(
        '边缘淡出',
        p.edgeFade.enabled,
        (v) => update(
          p.copyWith(
            edgeFade: v
                ? const LyricEdgeFade.fraction(top: .12, bottom: .2)
                : const LyricEdgeFade.none(),
          ),
        ),
      ),
      if (p.edgeFade.enabled) ...[
        _choice(
          '淡出单位',
          p.edgeFade.isFraction,
          const {true: '比例', false: '像素'},
          (v) => update(
            p.copyWith(
              edgeFade: v
                  ? const LyricEdgeFade.fraction(top: .12, bottom: .2)
                  : const LyricEdgeFade.pixels(top: 32, bottom: 48),
            ),
          ),
        ),
        _slider(
          '顶部淡出',
          p.edgeFade.top,
          0,
          p.edgeFade.isFraction ? .5 : 160,
          (v) => update(
            p.copyWith(
              edgeFade: p.edgeFade.isFraction
                  ? LyricEdgeFade.fraction(top: v, bottom: p.edgeFade.bottom)
                  : LyricEdgeFade.pixels(top: v, bottom: p.edgeFade.bottom),
            ),
          ),
          percent: p.edgeFade.isFraction,
          unit: p.edgeFade.isFraction ? '' : 'px',
        ),
        _slider(
          '底部淡出',
          p.edgeFade.bottom,
          0,
          p.edgeFade.isFraction ? .5 : 160,
          (v) => update(
            p.copyWith(
              edgeFade: p.edgeFade.isFraction
                  ? LyricEdgeFade.fraction(top: p.edgeFade.top, bottom: v)
                  : LyricEdgeFade.pixels(top: p.edgeFade.top, bottom: v),
            ),
          ),
          percent: p.edgeFade.isFraction,
          unit: p.edgeFade.isFraction ? '' : 'px',
        ),
      ],
    ];
  }

  List<Widget> _interaction() => [
    _section('01', '把控制权交给听众', '滑动浏览、点按跳转，然后回到音乐。'),
    _toggle('允许手势交互', p.interactive, (v) => update(p.copyWith(interactive: v))),
    if (p.displayMode == LyricDisplayMode.activeLine)
      _note('单行模式只展示当前句；切换到多行模式可体验滚动选句。'),
    _choice('选句吸附', p.selectionSnapMode, const {
      LyricSelectionSnapMode.none: '关闭',
      LyricSelectionSnapMode.afterScroll: '滚动后',
      LyricSelectionSnapMode.onDragPause: '拖动停顿',
    }, (v) => update(p.copyWith(selectionSnapMode: v))),
    _slider(
      '吸附等待',
      p.selectionSnapDelay.inMilliseconds.toDouble(),
      0,
      2000,
      (v) => update(
        p.copyWith(selectionSnapDelay: Duration(milliseconds: v.round())),
      ),
      unit: 'ms',
    ),
    _section('02', '自动回到此刻', '暂停浏览后，决定何时重新跟随播放。'),
    _toggle(
      '自动恢复跟随',
      p.resumeDelay != null,
      (v) => update(
        v
            ? p.copyWith(resumeDelay: const Duration(seconds: 3))
            : p.copyWith(clearResumeDelay: true),
      ),
    ),
    if (p.resumeDelay != null)
      _slider(
        '恢复等待',
        p.resumeDelay!.inMilliseconds.toDouble(),
        0,
        10000,
        (v) =>
            update(p.copyWith(resumeDelay: Duration(milliseconds: v.round()))),
        unit: 'ms',
      ),
    _toggle(
      '点按后恢复跟随',
      p.resumeOnTap,
      (v) => update(p.copyWith(resumeOnTap: v)),
    ),
    _note('舞台中的选句浮条支持播放这一句与手动恢复跟随。原版对照与当前版本共享同一播放进度。'),
  ];

  void _highlightColor(Color color, bool end) {
    final gradient = p.highlight.gradient;
    update(
      p.copyWith(
        highlight: gradient == null
            ? LyricHighlight.solid(
                color,
                tailFadeWidth: p.highlight.tailFadeWidth,
              )
            : LyricHighlight.gradient(
                LinearGradient(
                  colors: [
                    end ? gradient.colors.first : color,
                    end ? color : gradient.colors.last,
                  ],
                ),
                tailFadeWidth: p.highlight.tailFadeWidth,
              ),
      ),
    );
  }

  Widget _section(String number, String title, String caption) => Padding(
    padding: const EdgeInsets.only(top: 10, bottom: 20),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              number,
              style: const TextStyle(
                fontSize: 10,
                fontFamily: 'monospace',
                color: studioAccent,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              title,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
            ),
          ],
        ),
        const SizedBox(height: 7),
        Text(
          caption,
          style: const TextStyle(fontSize: 11, height: 1.6, color: studioMuted),
        ),
      ],
    ),
  );

  Widget _slider(
    String label,
    double value,
    double min,
    double max,
    ValueChanged<double> change, {
    String unit = '',
    bool percent = false,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: Column(
      children: [
        Row(
          children: [
            Expanded(child: Text(label, style: const TextStyle(fontSize: 12))),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              decoration: BoxDecoration(
                color: const Color(0xFFECEEE6),
                borderRadius: BorderRadius.circular(5),
              ),
              child: Text(
                percent
                    ? '${(value * 100).round()}%'
                    : '${value.round()} $unit',
                style: const TextStyle(
                  fontSize: 10,
                  color: studioAccent,
                  fontFamily: 'monospace',
                ),
              ),
            ),
          ],
        ),
        SizedBox(
          height: 32,
          child: Semantics(
            label: label,
            child: Slider(
              key: ValueKey('slider-$label'),
              value: value.clamp(min, max),
              min: min,
              max: max,
              label: percent
                  ? '${(value * 100).round()}%'
                  : '${value.round()} $unit',
              semanticFormatterCallback: (v) =>
                  percent ? '${(v * 100).round()}%' : '${v.round()} $unit',
              onChangeStart: (_) {
                _scrollStart = p.scrollAnimation;
                widget.state.beginGesture();
              },
              onChanged: change,
              onChangeEnd: (_) {
                widget.state.endGesture();
                _scrollStart = null;
              },
            ),
          ),
        ),
      ],
    ),
  );

  Widget _choice<T>(
    String label,
    T value,
    Map<T, String> choices,
    ValueChanged<T> change,
  ) => Padding(
    padding: const EdgeInsets.only(bottom: 18),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 12)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 5,
          runSpacing: 6,
          children: [
            for (final entry in choices.entries)
              Semantics(
                selected: entry.key == value,
                child: InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: () => change(entry.key),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 9,
                    ),
                    decoration: BoxDecoration(
                      color: entry.key == value
                          ? const Color(0xFFE4EBD9)
                          : Colors.white,
                      border: Border.all(
                        color: entry.key == value
                            ? const Color(0xFFA5B893)
                            : studioLine,
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      entry.value,
                      style: TextStyle(
                        fontSize: 11,
                        color: entry.key == value ? studioAccent : studioMuted,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ],
    ),
  );

  Widget _toggle(String label, bool value, ValueChanged<bool> change) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Row(
          children: [
            Expanded(child: Text(label, style: const TextStyle(fontSize: 12))),
            Switch.adaptive(value: value, onChanged: change),
          ],
        ),
      );

  Widget _palette(String label, Color color, ValueChanged<Color> change) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(fontSize: 12)),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final (name, swatch) in [
                  ('月白', const Color(0xFFFFFFFF)),
                  ('苔绿', const Color(0xFFD5EDAD)),
                  ('冰蓝', const Color(0xFF90E9EE)),
                  ('浅紫', const Color(0xFFB3A1FF)),
                  ('樱粉', const Color(0xFFF49AFF)),
                  ('日光黄', const Color(0xFFFFEB3B)),
                  ('橙色', const Color(0xFFFF9800)),
                  ('红色', const Color(0xFFF44336)),
                ])
                  Tooltip(
                    message: name,
                    child: Semantics(
                      label: '$label：$name',
                      button: true,
                      child: InkWell(
                        onTap: () => change(swatch),
                        customBorder: const CircleBorder(),
                        child: Container(
                          width: 26,
                          height: 26,
                          decoration: BoxDecoration(
                            color: swatch,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: color.withValues(alpha: 1) == swatch
                                  ? studioInk
                                  : studioLine,
                              width: color.withValues(alpha: 1) == swatch
                                  ? 2
                                  : 1,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      );
  Widget _note(String text) => Container(
    margin: const EdgeInsets.only(bottom: 16),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: const Color(0xFFECEEE6),
      borderRadius: BorderRadius.circular(10),
    ),
    child: Text(
      text,
      style: const TextStyle(fontSize: 11, color: studioMuted, height: 1.7),
    ),
  );
}
