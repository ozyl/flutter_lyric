// @dart=3.8

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_lyric/flutter_lyric.dart';
import 'studio_state.dart';
import 'demo_line_transitions.dart';
import 'scroll_tuning.dart';
import 'studio_theme.dart';
import 'preset_export.dart';
import 'preset_help.dart';

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
  LyricPreset? _copiedPreset;
  LyricPreset get p => widget.state.preset;
  TextStyle get _activeText => p.textStyle.merge(p.activeTextStyle);
  TextStyle get _activeTranslation =>
      (p.translationInheritsTextStyle ? p.textStyle : const TextStyle())
          .merge(p.translationTextStyle)
          .merge(p.activeTranslationTextStyle);
  void update(LyricPreset value) => widget.state.update(value);

  Future<bool> _copyCode(String code, LyricPreset source) async {
    try {
      await Clipboard.setData(ClipboardData(text: code));
      if (!mounted) return false;
      setState(() => _copiedPreset = source);
      return true;
    } catch (_) {
      if (!mounted) return false;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('剪贴板不可用，请打开代码预览后手动选择复制'),
          action: SnackBarAction(
            label: '查看代码',
            onPressed: () => _showCode(code, source),
          ),
        ),
      );
      return false;
    }
  }

  void _export({bool preview = false}) {
    try {
      final code = exportPreset(widget.state.selected, p);
      if (preview) {
        _showCode(code, p);
      } else {
        _copyCode(code, p);
      }
    } on UnsupportedError catch (error) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('无法完整导出：${error.message}')));
    }
  }

  void _showCode(String code, LyricPreset source) => showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('应用到你的项目'),
      content: SizedBox(
        width: 640,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '复制以下 Dart 代码，将 lyricPreset 传给 LyricView 的 preset。'
                '歌词加载和播放进度由你已有的 LyricController 提供。\n\n'
                '配置包含当前风格和本次调整。背景、播放器和示例选句浮条由应用自行实现。',
                style: TextStyle(fontSize: 12, height: 1.6),
              ),
              const SizedBox(height: 16),
              SelectableText(
                code,
                key: const ValueKey('preset-code'),
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 12,
                  height: 1.6,
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('关闭'),
        ),
        FilledButton.icon(
          onPressed: () async {
            final copied = await _copyCode(code, source);
            if (copied && context.mounted) Navigator.pop(context);
          },
          icon: const Icon(Icons.copy_rounded, size: 16),
          label: const Text('复制代码'),
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final compact = constraints.maxHeight < 420;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (!compact) _header(compact: false),
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
                              color: _tab == i
                                  ? Colors.white
                                  : Colors.transparent,
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
              children: [
                if (compact) _header(compact: true),
                ...switch (_tab) {
                  0 => _typography(),
                  1 => _layout(),
                  2 => _motion(),
                  _ => _interaction(),
                },
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: studioLine)),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        key: const ValueKey('copy-preset'),
                        onPressed: _export,
                        icon: Icon(
                          _copiedPreset == p
                              ? Icons.check_rounded
                              : Icons.copy_rounded,
                          size: 16,
                        ),
                        label: const Text('复制配置'),
                      ),
                    ),
                    const SizedBox(width: 4),
                    TextButton(
                      onPressed: widget.state.isModified(widget.state.selected)
                          ? widget.state.reset
                          : null,
                      child: const Text('重置', style: TextStyle(fontSize: 12)),
                    ),
                    IconButton(
                      tooltip: '查看接入代码',
                      onPressed: () => _export(preview: true),
                      icon: const Icon(Icons.code_rounded, size: 20),
                    ),
                  ],
                ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    _copiedPreset == p
                        ? '已复制 Dart 配置，可粘贴到项目中使用'
                        : widget.state.isModified(widget.state.selected)
                        ? '已修改 · 关闭应用前请复制保存'
                        : '默认配置 · 修改会实时预览',
                    style: const TextStyle(fontSize: 10, color: studioMuted),
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    },
  );

  Widget _header({required bool compact}) => Padding(
    padding: EdgeInsets.fromLTRB(
      compact ? 0 : 20,
      compact ? 0 : 18,
      compact ? 0 : 12,
      compact ? 4 : 12,
    ),
    child: Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!compact) ...[
                const StudioLabel('LYRIC PRESET'),
                const SizedBox(height: 6),
              ],
              Text(
                '调节 · ${widget.state.selected.name}',
                style: TextStyle(
                  fontSize: compact ? 16 : 18,
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
  );

  List<Widget> _typography() => [
    _section('01', '歌词文字', '当前句指正在播放的歌词。每项说明右侧的代码图标可查看对应 API 字段。'),
    if (p.layoutMode == LyricLayoutMode.fixed)
      _note('「保持换行位置」按当前句样式统一排版。当前句字号未单独设置时仍沿用正文大小；要让两种字号分别换行，请在布局中切换。'),
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
      _activeText.fontSize ?? 18,
      10,
      60,
      (v) => update(
        p.copyWith(activeTextStyle: p.activeTextStyle.copyWith(fontSize: v)),
      ),
      unit: 'px',
    ),
    _choice(
      '当前句字重',
      _activeText.fontWeight ?? FontWeight.normal,
      {
        FontWeight.w400: '常规 400',
        FontWeight.w500: '中等 500',
        FontWeight.w600: '半粗 600',
        FontWeight.w700: '加粗 700',
        FontWeight.w800: '特粗 800',
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
      '当前句文字透明度',
      (_activeText.color ?? Colors.white).a,
      0,
      1,
      (v) => update(
        p.copyWith(
          activeTextStyle: p.activeTextStyle.copyWith(
            color: (_activeText.color ?? Colors.white).withValues(alpha: v),
          ),
        ),
      ),
      percent: true,
    ),
    _palette(
      '当前句文字颜色',
      _activeText.color ?? Colors.white,
      (v) => update(
        p.copyWith(
          activeTextStyle: p.activeTextStyle.copyWith(
            color: v.withValues(alpha: (_activeText.color ?? Colors.white).a),
          ),
        ),
      ),
    ),
    _section('02', '歌词译文', '每句歌词下方的翻译，可与正文分别设置。'),
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
      _activeTranslation.fontSize ?? 12,
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
    _section('01', '显示与换行', '先选择显示范围，再决定长句在播放切换时如何换行。'),
    _choice('显示方式', p.displayMode, const {
      LyricDisplayMode.scrollable: '多行列表',
      LyricDisplayMode.activeLine: '仅当前句',
    }, (v) => update(p.copyWith(displayMode: v))),
    _choice('长句换行方式', p.layoutMode, const {
      LyricLayoutMode.dualStyle: '随字号重新换行',
      LyricLayoutMode.fixed: '保持换行位置',
    }, (value) => update(p.copyWith(layoutMode: value))),
    _note(
      p.layoutMode == LyricLayoutMode.dualStyle
          ? '当前采用两套排版：普通句用正文样式，当前句用当前句样式。比如字号从 23 变为 30 后，同一句可能从两行变成三行。'
          : '当前统一按当前句样式计算换行，播放切换时保持断行位置，通过绘制动效变化。适合希望长句不在切句时重新换行的界面。',
    ),
    _section('02', '对齐与间距', '文字对齐影响换行后的每一行；内容对齐影响整块歌词的位置。'),
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
    _section('03', '歌词停留位置', '决定当前句和手动选择句停在多高。打开预览辅助线可看到对应位置。'),
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
      '$label定位方式',
      anchor.isFraction,
      const {true: '按区域高度', false: '距顶部像素'},
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
        LyricAnchorTarget.mainText: '正文中心',
        LyricAnchorTarget.translationText: '译文中心',
        LyricAnchorTarget.lineCenter: '含译文的整体中心',
      },
      (v) => change(
        anchor.isFraction
            ? LyricAnchor.fraction(anchor.position, target: v)
            : LyricAnchor.pixels(anchor.position, target: v),
      ),
    ),
  ];

  void _wordEffects({
    double? lift,
    double? floatAmplitude,
    Duration? liftDuration,
    Duration? floatPeriod,
    Duration? floatStagger,
    LyricFloatMode? floatMode,
    bool? simulateTiming,
  }) {
    final current = p.wordEffects;
    update(
      p.copyWith(
        wordEffects: LyricWordEffects(
          lift: lift ?? current.lift,
          liftDuration: liftDuration ?? current.liftDuration,
          floatAmplitude: floatAmplitude ?? current.floatAmplitude,
          floatPeriod: floatPeriod ?? current.floatPeriod,
          floatStagger: floatStagger ?? current.floatStagger,
          floatMode: floatMode ?? current.floatMode,
          simulateTiming: simulateTiming ?? current.simulateTiming,
        ),
      ),
    );
  }

  void _lineMotion({
    Duration? delay,
    Duration? maxDelay,
    Duration? waveDuration,
    double? waveAmplitude,
    double? maxLag,
  }) {
    final current = p.lineMotion;
    update(
      p.copyWith(
        lineMotion: LyricLineMotion(
          delay: delay ?? current.delay,
          maxDelay: maxDelay ?? current.maxDelay,
          waveDuration: waveDuration ?? current.waveDuration,
          waveAmplitude: waveAmplitude ?? current.waveAmplitude,
          maxLag: maxLag ?? current.maxLag,
        ),
      ),
    );
  }

  List<Widget> _motion() {
    final transitions = {
      for (final item in demoLineTransitions)
        item.name: item.forMode(p.displayMode),
    };
    final scroll = p.scrollAnimation.resolve(100);
    final curveName = _curves.entries
        .where((e) => e.value == scroll.curve)
        .firstOrNull
        ?.key;
    final transitionName =
        transitions.entries
            .where(
              (entry) =>
                  entry.value.enabled == p.lineTransition.enabled &&
                  entry.value.legacyScale == p.lineTransition.legacyScale &&
                  entry.value.resolver == p.lineTransition.resolver &&
                  listEquals(entry.value.effects, p.lineTransition.effects),
            )
            .firstOrNull
            ?.key ??
        '当前自定义';
    return [
      _section(
        '01',
        '当前句切换',
        '${demoLineTransitions.length} 种动画，控制歌词变为当前句、退出当前句时的视觉变化。',
      ),
      _choice(
        '切句动画',
        transitionName,
        {
          for (final name in transitions.keys) name: name,
          if (transitionName == '当前自定义') '当前自定义': '当前自定义',
        },
        (value) {
          if (transitions[value] != null) {
            update(p.copyWith(lineTransition: transitions[value]));
          }
        },
      ),
      _note(
        demoLineTransitions
                .where((item) => item.name == transitionName)
                .firstOrNull
                ?.description ??
            '保留当前自定义效果，时长可单独调整。',
      ),
      _section('02', '歌词列表与逐字运动', '列表滚动时的跟随方式，以及字词的上弹和悬浮效果。'),
      _choice(
        '行间运动',
        p.lineMotion.waveAmplitude > 0
            ? 2
            : p.lineMotion.maxLag > 0
            ? 1
            : 0,
        const {0: '同步移动', 1: '错位移动', 2: '波浪移动'},
        (value) => update(
          p.copyWith(
            lineMotion: value == 0
                ? const LyricLineMotion()
                : LyricLineMotion(
                    delay: const Duration(milliseconds: 35),
                    maxDelay: const Duration(milliseconds: 140),
                    maxLag: 64,
                    waveAmplitude: value == 2 ? 12 : 0,
                    waveDuration: const Duration(milliseconds: 600),
                  ),
          ),
        ),
      ),
      if (p.lineMotion.maxLag > 0 || p.lineMotion.waveAmplitude > 0) ...[
        _slider(
          '行间延迟',
          p.lineMotion.delay.inMilliseconds.toDouble(),
          0,
          100,
          (v) => _lineMotion(delay: Duration(milliseconds: v.round())),
          unit: 'ms',
        ),
        _slider(
          '最大延迟',
          p.lineMotion.maxDelay.inMilliseconds.toDouble(),
          0,
          500,
          (v) => _lineMotion(maxDelay: Duration(milliseconds: v.round())),
          unit: 'ms',
        ),
        _slider(
          '行间错位',
          p.lineMotion.maxLag,
          0,
          120,
          (v) => _lineMotion(maxLag: v),
          unit: 'px',
        ),
      ],
      if (p.lineMotion.waveAmplitude > 0) ...[
        _slider(
          '波浪幅度',
          p.lineMotion.waveAmplitude,
          0,
          24,
          (v) => _lineMotion(waveAmplitude: v),
          unit: 'px',
        ),
        _slider(
          '波浪时长',
          p.lineMotion.waveDuration.inMilliseconds.toDouble(),
          0,
          1500,
          (v) => _lineMotion(waveDuration: Duration(milliseconds: v.round())),
          unit: 'ms',
        ),
      ],
      _toggle(
        '超过一屏直接定位',
        p.jumpScrollThreshold != null,
        (value) => update(
          p.copyWith(
            jumpScrollThreshold: value ? 1 : null,
            clearJumpScrollThreshold: !value,
          ),
        ),
      ),
      _slider(
        '远处模糊',
        p.distanceBlur.maxSigma,
        0,
        8,
        (value) => update(
          p.copyWith(
            distanceBlur: LyricDistanceBlur(
              maxSigma: value,
              sigmaPerLine: p.distanceBlur.sigmaPerLine,
              whenBrowsing: p.distanceBlur.whenBrowsing,
            ),
          ),
        ),
        unit: 'σ',
      ),
      if (p.distanceBlur.maxSigma > 0)
        _toggle(
          '滑动选择时保持清晰',
          !p.distanceBlur.whenBrowsing,
          (value) => update(
            p.copyWith(
              distanceBlur: LyricDistanceBlur(
                maxSigma: p.distanceBlur.maxSigma,
                sigmaPerLine: p.distanceBlur.sigmaPerLine,
                whenBrowsing: !value,
              ),
            ),
          ),
        ),
      _slider(
        '逐字上弹',
        p.wordEffects.lift,
        0,
        12,
        (value) => _wordEffects(lift: value),
        unit: 'px',
      ),
      if (p.wordEffects.lift > 0)
        _slider(
          '上弹时长',
          p.wordEffects.liftDuration.inMilliseconds.toDouble(),
          0,
          1500,
          (v) => _wordEffects(liftDuration: Duration(milliseconds: v.round())),
          unit: 'ms',
        ),
      _slider(
        '逐字悬浮',
        p.wordEffects.floatAmplitude,
        0,
        6,
        (value) => _wordEffects(floatAmplitude: value),
        unit: 'px',
      ),
      if (p.wordEffects.floatAmplitude > 0) ...[
        _choice('悬浮模式', p.wordEffects.floatMode, const {
          LyricFloatMode.highlighted: '仅高亮文字',
          LyricFloatMode.all: '当前句全部文字',
        }, (value) => _wordEffects(floatMode: value)),
        _slider(
          '悬浮周期',
          p.wordEffects.floatPeriod.inMilliseconds.toDouble(),
          2400,
          10000,
          (v) => _wordEffects(floatPeriod: Duration(milliseconds: v.round())),
          unit: 'ms',
        ),
        _slider(
          '相邻字符延迟',
          p.wordEffects.floatStagger.inMilliseconds.toDouble(),
          0,
          500,
          (v) => _wordEffects(floatStagger: Duration(milliseconds: v.round())),
          unit: 'ms',
        ),
      ],
      _toggle(
        'LRC 模拟逐字时间',
        p.wordEffects.simulateTiming,
        (value) => _wordEffects(simulateTiming: value),
      ),
      _section('03', '已唱文字高亮', '有逐字时间时按字点亮；普通 LRC 在已知句子时长内线性推进。'),
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
        '04',
        '滚动时间与速度',
        p.scrollAnimation.resolver != null
            ? '保留预设的距离时长计算；调整会按比例缩放。'
            : '时长决定多久到达下一句；曲线决定中途如何加速或减速。',
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
      if (p.lineTransition.enabled) ...[
        _slider(
          '进入时长',
          p.lineTransition.enterDuration.inMilliseconds.toDouble(),
          0,
          1500,
          (v) => update(
            p.copyWith(
              lineTransition: p.lineTransition.copyWith(
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
              lineTransition: p.lineTransition.copyWith(
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
      _section('05', '顶部与底部渐隐', '靠近歌词区域边缘的文字逐渐透明。'),
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
      ..._countdown(),
    ];
  }

  List<Widget> _countdown() => [
    _section(
      '06',
      '前奏与间奏小圆点',
      '空白段需放得下完整的小圆点时长；多余时间可先呼吸等待。已知开唱时间时，可借用前奏中的署名时间。样式随预设适配。',
    ),
    _toggle(
      '显示圆点倒计时',
      p.countdown.enabled,
      (v) => update(p.copyWith(countdown: p.countdown.copyWith(enabled: v))),
    ),
    if (p.countdown.enabled) ...[
      _slider(
        '小圆点数量',
        p.countdown.dotCount.toDouble(),
        1,
        8,
        (v) => update(
          p.copyWith(countdown: p.countdown.copyWith(dotCount: v.round())),
        ),
      ),
      _slider(
        '小圆点时长',
        p.countdown.dotDuration.inMilliseconds / 1000,
        .5,
        15,
        (v) => update(
          p.copyWith(
            countdown: p.countdown.copyWith(
              dotDuration: Duration(milliseconds: (v * 1000).round()),
            ),
          ),
        ),
        unit: 's',
      ),
      _slider(
        '小圆点呼吸时长',
        p.countdown.breathDuration.inMilliseconds / 1000,
        0,
        30,
        (v) => update(
          p.copyWith(
            countdown: p.countdown.copyWith(
              breathDuration: Duration(milliseconds: (v * 1000).round()),
            ),
          ),
        ),
        unit: 's',
      ),
    ],
  ];

  List<Widget> _interaction() => [
    _section('01', '浏览与选句', '用户可以拖动浏览歌词，并将选中句对齐到指定位置。'),
    _toggle('允许手势交互', p.interactive, (v) => update(p.copyWith(interactive: v))),
    if (p.displayMode == LyricDisplayMode.activeLine)
      _note('单行模式只展示当前句；切换到多行模式可体验滚动选句。'),
    _choice('选句吸附', p.selectionSnapMode, const {
      LyricSelectionSnapMode.none: '关闭',
      LyricSelectionSnapMode.afterScroll: '滚动后',
      LyricSelectionSnapMode.onDragPause: '拖动停顿',
    }, (v) => update(p.copyWith(selectionSnapMode: v))),
    if (p.selectionSnapMode != LyricSelectionSnapMode.none)
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
    _section('02', '恢复播放跟随', '跟随是将视图移回当前播放句；与播放器跳转是两个独立行为。'),
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
    _note(
      '接入时在 LyricView.onLineTap 中使用 details.seekPosition 跳转播放器。示例的选句浮条由应用提供，复制配置后需自行实现。',
    ),
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
      crossAxisAlignment: CrossAxisAlignment.start,
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
                _sliderValue(value, unit, percent),
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
              label: _sliderValue(value, unit, percent),
              semanticFormatterCallback: (v) => _sliderValue(v, unit, percent),
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
        ..._help(label),
      ],
    ),
  );

  String _sliderValue(double value, String unit, bool percent) => percent
      ? '${(value * 100).round()}%'
      : '${value.toStringAsFixed(1).replaceFirst(RegExp(r'\.0$'), '')} $unit'
            .trim();

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
                  key: ValueKey('choice-$label-${entry.key}'),
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
        ..._help(label),
      ],
    ),
  );

  Widget _toggle(String label, bool value, ValueChanged<bool> change) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(label, style: const TextStyle(fontSize: 12)),
                ),
                Switch.adaptive(
                  key: ValueKey('toggle-$label'),
                  value: value,
                  onChanged: change,
                ),
              ],
            ),
            ..._help(label),
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
            ..._help(label),
          ],
        ),
      );
  List<Widget> _help(String label) {
    final help = helpForPresetControl(label);
    if (help == null) return const [];
    return [
      const SizedBox(height: 6),
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              help.description,
              style: const TextStyle(
                fontSize: 11,
                height: 1.5,
                color: studioMuted,
              ),
            ),
          ),
          const SizedBox(width: 6),
          Tooltip(
            message: 'LyricPreset.${help.api}',
            triggerMode: TooltipTriggerMode.tap,
            child: const Padding(
              padding: EdgeInsets.all(2),
              child: Icon(Icons.code_rounded, size: 16, color: studioMuted),
            ),
          ),
        ],
      ),
    ];
  }

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
