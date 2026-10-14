// @dart=3.8

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_lyric/flutter_lyric.dart';

import 'demo_presets.dart';

const _bases = <String, (String, LyricPreset)>{
  'moss': ('moss', LyricPresets.moss),
  'aurora': ('aurora', LyricPresets.aurora),
  'apple-music': ('appleMusic', LyricPresets.appleMusic),
  'cascade': ('cascade', LyricPresets.cascade),
  'pulse': ('pulse', LyricPresets.pulse),
  'cinema': ('cinema', LyricPresets.cinema),
  'float': ('drift', LyricPresets.drift),
};

const _transitions = <String, LyricLineTransition>{
  'none': LyricLineTransitions.none,
  'classic': LyricLineTransitions.classic,
  'fade': LyricLineTransitions.fade,
  'scale': LyricLineTransitions.scale,
  'slide': LyricLineTransitions.slide,
  'blur': LyricLineTransitions.blur,
  'slideFade': LyricLineTransitions.slideFade,
  'appleMusic': LyricLineTransitions.appleMusic,
  'rise': LyricLineTransitions.rise,
  'paper': LyricLineTransitions.paper,
  'spring': LyricLineTransitions.spring,
  'orbit': LyricLineTransitions.orbit,
  'pendulum': LyricLineTransitions.pendulum,
  'zoom': LyricLineTransitions.zoom,
  'step': LyricLineTransitions.step,
  'drift': LyricLineTransitions.drift,
  'focus': LyricLineTransitions.focus,
  'cinematic': LyricLineTransitions.cinematic,
};

const _curves = <String, Curve>{
  'linear': Curves.linear,
  'easeIn': Curves.easeIn,
  'easeOut': Curves.easeOut,
  'easeOutCubic': Curves.easeOutCubic,
  'easeInCubic': Curves.easeInCubic,
  'easeInOutCubic': Curves.easeInOutCubic,
  'easeOutBack': Curves.easeOutBack,
  'bounceOut': Curves.bounceOut,
  'elasticOut': Curves.elasticOut,
};

/// Exports Studio's editable configuration using only public package APIs.
/// Gallery-only styles start from Moss and include their visual differences.
String exportPreset(DemoPreset demo, LyricPreset preset) {
  final (name, base) = _bases[demo.id] ?? _bases['moss']!;
  final fields = <String>[];
  void add<T>(String name, T value, T original, String Function(T) encode) {
    if (value != original) fields.add('  $name: ${encode(value)},');
  }

  String literal(Object? value) => '$value';
  void nullable<T>(
    String name,
    T? value,
    T? original,
    String Function(T) encode,
  ) {
    if (value == original) return;
    if (value == null) {
      fields.add('  clear${name[0].toUpperCase()}${name.substring(1)}: true,');
    } else {
      fields.add('  $name: ${encode(value)},');
    }
  }

  add('displayMode', preset.displayMode, base.displayMode, literal);
  add('textStyle', preset.textStyle, base.textStyle, _textStyle);
  add(
    'activeTextStyle',
    preset.activeTextStyle,
    base.activeTextStyle,
    _textStyle,
  );
  add(
    'translationTextStyle',
    preset.translationTextStyle,
    base.translationTextStyle,
    _textStyle,
  );
  add(
    'translationInheritsTextStyle',
    preset.translationInheritsTextStyle,
    base.translationInheritsTextStyle,
    literal,
  );
  add(
    'activeTranslationTextStyle',
    preset.activeTranslationTextStyle,
    base.activeTranslationTextStyle,
    _textStyle,
  );
  nullable(
    'selectedTextColor',
    preset.selectedTextColor,
    base.selectedTextColor,
    _color,
  );
  nullable(
    'selectedTranslationTextColor',
    preset.selectedTranslationTextColor,
    base.selectedTranslationTextColor,
    _color,
  );
  add('textAlign', preset.textAlign, base.textAlign, literal);
  add(
    'contentAlignment',
    preset.contentAlignment,
    base.contentAlignment,
    literal,
  );
  add('padding', preset.padding, base.padding, (value) {
    if (value is! EdgeInsets) {
      throw UnsupportedError('暂不支持导出自定义方向边距。');
    }
    return 'const EdgeInsets.fromLTRB('
        '${value.left}, ${value.top}, ${value.right}, ${value.bottom})';
  });
  add('lineSpacing', preset.lineSpacing, base.lineSpacing, literal);
  add(
    'translationSpacing',
    preset.translationSpacing,
    base.translationSpacing,
    literal,
  );
  add('activeAnchor', preset.activeAnchor, base.activeAnchor, _anchor);
  add('selectionAnchor', preset.selectionAnchor, base.selectionAnchor, _anchor);
  add('highlight', preset.highlight, base.highlight, _highlight);
  add('countdown', preset.countdown, base.countdown, (v) {
    return 'LyricCountdown(\n'
        '    enabled: ${v.enabled},\n'
        '    dotCount: ${v.dotCount},\n'
        '    dotDuration: ${_duration(v.dotDuration)},\n'
        '    breathDuration: ${_duration(v.breathDuration)},\n'
        '    direction: ${v.direction},\n'
        '    dotSize: ${v.dotSize},\n'
        '    dotSpacing: ${v.dotSpacing},\n'
        '    color: ${v.color == null ? 'null' : _color(v.color!)},\n'
        '    inactiveColor: ${v.inactiveColor == null ? 'null' : _color(v.inactiveColor!)},\n'
        '    height: ${v.height},\n'
        '    spacing: ${v.spacing},\n'
        '  )';
  });
  add(
    'edgeFade',
    preset.edgeFade,
    base.edgeFade,
    (value) => value.enabled
        ? 'const LyricEdgeFade.${value.isFraction ? 'fraction' : 'pixels'}('
              'top: ${value.top}, bottom: ${value.bottom})'
        : 'const LyricEdgeFade.none()',
  );
  add('scrollAnimation', preset.scrollAnimation, base.scrollAnimation, _scroll);
  add(
    'lineTransition',
    preset.lineTransition,
    base.lineTransition,
    _transition,
  );
  add('layoutMode', preset.layoutMode, base.layoutMode, literal);
  add(
    'lineMotion',
    preset.lineMotion,
    base.lineMotion,
    (v) =>
        'const LyricLineMotion(\n'
        '    delay: ${_duration(v.delay)},\n'
        '    maxDelay: ${_duration(v.maxDelay)},\n'
        '    maxLag: ${v.maxLag},\n'
        '    waveAmplitude: ${v.waveAmplitude},\n'
        '    waveDuration: ${_duration(v.waveDuration)},\n'
        '  )',
  );
  add(
    'wordEffects',
    preset.wordEffects,
    base.wordEffects,
    (v) =>
        'const LyricWordEffects(\n'
        '    lift: ${v.lift},\n'
        '    liftDuration: ${_duration(v.liftDuration)},\n'
        '    floatAmplitude: ${v.floatAmplitude},\n'
        '    floatPeriod: ${_duration(v.floatPeriod)},\n'
        '    floatStagger: ${_duration(v.floatStagger)},\n'
        '    floatMode: ${v.floatMode},\n'
        '    simulateTiming: ${v.simulateTiming},\n'
        '  )',
  );
  add(
    'distanceBlur',
    preset.distanceBlur,
    base.distanceBlur,
    (v) =>
        'const LyricDistanceBlur(maxSigma: ${v.maxSigma}, '
        'sigmaPerLine: ${v.sigmaPerLine}, whenBrowsing: ${v.whenBrowsing})',
  );
  nullable(
    'jumpScrollThreshold',
    preset.jumpScrollThreshold,
    base.jumpScrollThreshold,
    literal,
  );
  add('interactive', preset.interactive, base.interactive, literal);
  add(
    'selectionSnapMode',
    preset.selectionSnapMode,
    base.selectionSnapMode,
    literal,
  );
  add(
    'selectionSnapDelay',
    preset.selectionSnapDelay,
    base.selectionSnapDelay,
    (v) => 'const ${_duration(v)}',
  );
  nullable(
    'resumeDelay',
    preset.resumeDelay,
    base.resumeDelay,
    (v) => 'const ${_duration(v)}',
  );
  add('resumeOnTap', preset.resumeOnTap, base.resumeOnTap, literal);

  // Builders are application code; never silently replace them with placeholders.
  if (preset.emptyBuilder != base.emptyBuilder ||
      preset.selectionBackgroundBuilder != base.selectionBackgroundBuilder ||
      preset.selectionForegroundBuilder != base.selectionForegroundBuilder) {
    throw UnsupportedError('自定义 Widget builder 需要在接入项目中手动保留。');
  }

  final expression = fields.isEmpty
      ? 'LyricPresets.$name'
      : 'LyricPresets.$name.copyWith(\n${fields.join('\n')}\n)';
  final usesFlutterTypes = RegExp(
    r'\b(TextStyle|TextAlign|EdgeInsets|LinearGradient|Color|Alignment|AlignmentDirectional|Curves|FontWeight|FontStyle|TileMode)\b',
  ).hasMatch(expression);
  final flutterImport = usesFlutterTypes
      ? "import 'package:flutter/material.dart';\n"
      : '';
  return "${flutterImport}import 'package:flutter_lyric/flutter_lyric.dart';\n\n"
      '// ${demo.name} · 当前配置\n'
      'final lyricPreset = $expression;\n\n'
      '// 在已有播放器页面的 build 方法中使用：\n'
      '// LyricView(controller: lyricController, preset: lyricPreset)\n'
      '// lyricController 由你的播放器加载歌词并同步播放进度。\n';
}

String _duration(Duration value) => value.inMicroseconds % 1000 == 0
    ? 'Duration(milliseconds: ${value.inMilliseconds})'
    : 'Duration(microseconds: ${value.inMicroseconds})';

String _color(Color value) {
  final argb = value.toARGB32();
  final hex = argb.toRadixString(16).padLeft(8, '0').toUpperCase();
  final exact = Color(argb);
  if (exact == value) return 'const Color(0x$hex)';
  return 'const Color(0x$hex).withValues('
      'alpha: ${value.a}, red: ${value.r}, green: ${value.g}, blue: ${value.b})';
}

String _textStyle(TextStyle v) {
  final fields = <String>[
    if (!v.inherit) 'inherit: false',
    if (v.fontSize != null) 'fontSize: ${v.fontSize}',
    if (v.fontWeight != null) 'fontWeight: ${v.fontWeight}',
    if (v.fontStyle != null) 'fontStyle: ${v.fontStyle}',
    if (v.fontFamily != null) 'fontFamily: ${_string(v.fontFamily!)}',
    if (v.color != null) 'color: ${_color(v.color!)}',
    if (v.height != null) 'height: ${v.height}',
    if (v.letterSpacing != null) 'letterSpacing: ${v.letterSpacing}',
    if (v.wordSpacing != null) 'wordSpacing: ${v.wordSpacing}',
  ];
  // The inspector edits these fields. Reject a future richer style until its
  // serializer is added, so copied code can never silently lose its appearance.
  final supported = TextStyle(
    inherit: v.inherit,
    fontSize: v.fontSize,
    fontWeight: v.fontWeight,
    fontStyle: v.fontStyle,
    fontFamily: v.fontFamily,
    color: v.color,
    height: v.height,
    letterSpacing: v.letterSpacing,
    wordSpacing: v.wordSpacing,
  );
  if (supported != v) throw UnsupportedError('当前文字样式含有尚未支持导出的属性。');
  return 'TextStyle(${fields.join(', ')})';
}

String _string(String value) => jsonEncode(value).replaceAll(r'$', r'\$');

String _anchor(LyricAnchor v) =>
    'const LyricAnchor.${v.isFraction ? 'fraction' : 'pixels'}('
    '${v.position}, target: ${v.target})';

String _highlight(LyricHighlight value) {
  if (!value.enabled) return 'const LyricHighlight.none()';
  final gradient = value.gradient;
  if (gradient == null) {
    return 'LyricHighlight.solid(${_color(value.color!)}, '
        'tailFadeWidth: ${value.tailFadeWidth})';
  }
  if (gradient.transform != null) {
    throw UnsupportedError('暂不支持导出自定义渐变变换。');
  }
  return 'LyricHighlight.gradient(\n'
      '    LinearGradient(\n'
      '      colors: [${gradient.colors.map(_color).join(', ')}],\n'
      '      begin: ${_alignment(gradient.begin)},\n'
      '      end: ${_alignment(gradient.end)},\n'
      '      stops: ${gradient.stops == null ? 'null' : '[${gradient.stops!.join(', ')}]'},\n'
      '      tileMode: ${gradient.tileMode},\n'
      '    ),\n'
      '    tailFadeWidth: ${value.tailFadeWidth},\n'
      '  )';
}

String _alignment(AlignmentGeometry value) => switch (value) {
  Alignment v => 'const Alignment(${v.x}, ${v.y})',
  AlignmentDirectional v => 'const AlignmentDirectional(${v.start}, ${v.y})',
  _ => throw UnsupportedError('暂不支持导出自定义渐变方向。'),
};

String _curve(Curve value) {
  for (final entry in _curves.entries) {
    if (entry.value == value) return 'Curves.${entry.key}';
  }
  throw UnsupportedError('自定义曲线需要在接入项目中手动实现。');
}

String _scroll(LyricScrollAnimation value) {
  if (value.resolver != null) {
    throw UnsupportedError('自定义滚动计算需要在接入项目中手动实现。');
  }
  if (value.durations.isEmpty) {
    return 'LyricScrollAnimation.fixed('
        'duration: ${_duration(value.duration)}, curve: ${_curve(value.curve)})';
  }
  return 'LyricScrollAnimation.byDistance(\n'
      '    durations: {${value.durations.entries.map((e) => '${e.key}: ${_duration(e.value)}').join(', ')}},\n'
      '    duration: ${_duration(value.duration)},\n'
      '    curve: ${_curve(value.curve)},\n'
      '  )';
}

String _transition(LyricLineTransition value) {
  for (final entry in _transitions.entries) {
    final base = entry.value;
    if (base.enabled != value.enabled ||
        base.legacyScale != value.legacyScale ||
        base.resolver != value.resolver ||
        !listEquals(base.effects, value.effects) ||
        base.maxDisplacement != value.maxDisplacement ||
        base.maxBlurSigma != value.maxBlurSigma ||
        base.maxScale != value.maxScale) {
      continue;
    }
    final fields = <String>[
      if (value.enterDuration != base.enterDuration)
        'enterDuration: ${_duration(value.enterDuration)}',
      if (value.exitDuration != base.exitDuration)
        'exitDuration: ${_duration(value.exitDuration)}',
      if (value.enterCurve != base.enterCurve)
        'enterCurve: ${_curve(value.enterCurve)}',
      if (value.exitCurve != base.exitCurve)
        'exitCurve: ${_curve(value.exitCurve)}',
    ];
    return 'LyricLineTransitions.${entry.key}'
        '${fields.isEmpty ? '' : '.copyWith(${fields.join(', ')})'}';
  }
  throw UnsupportedError('自定义切句动画需要在接入项目中手动实现。');
}
