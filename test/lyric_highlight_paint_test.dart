import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_lyric/core/lyric_model.dart';
import 'package:flutter_lyric/core/lyric_style.dart';
import 'package:flutter_lyric/core/lyric_styles.dart';
import 'package:flutter_lyric/render/lyric_layout.dart';
import 'package:flutter_lyric/render/lyric_painter.dart';
import 'package:flutter_lyric/widgets/mixins/lyric_line_switch_mixin.dart';
import 'package:flutter_test/flutter_test.dart';

const _size = Size(200, 100);
const _textColor = Color(0x80FF0000);
const _highlightColor = Color(0xFF0000FF);

LyricStyle get _style => LyricStyles.default1.copyWith(
      textStyle: const TextStyle(fontSize: 40, height: 1.2, color: _textColor),
      activeStyle: const TextStyle(fontSize: 40, height: 1.2, color: _textColor),
      contentPadding: EdgeInsets.zero,
      activeHighlightColor: _highlightColor,
      enableSwitchAnimation: false,
    );

LyricPainter _painter({
  required LyricLine line,
  required double highlightWidth,
}) {
  return LyricPainter(
    layout: LyricLayout.compute(
      LyricModel(lines: [line]),
      _style,
      _size,
    ),
    playIndex: 0,
    scrollY: 0,
    activeHighlightWidth: highlightWidth,
    switchState: LyricLineSwitchState(
      exitAnimationValue: 1,
      enterAnimationValue: 1,
      exitIndex: -1,
      enterIndex: -1,
    ),
    isSelecting: false,
    style: _style,
    onAnchorIndexChange: (_) {},
    onShowLineRectsChange: (_) {},
  );
}

Future<List<int>> _paintStats(LyricPainter painter) async {
  final recorder = ui.PictureRecorder();
  painter.paint(Canvas(recorder), _size);
  final image = await recorder
      .endRecording()
      .toImage(_size.width.toInt(), _size.height.toInt());
  final pixels = (await image.toByteData())!.buffer.asUint8List();
  var maxAlpha = 0;
  var maxRed = 0;
  var maxBlue = 0;
  for (var i = 0; i < pixels.length; i += 4) {
    if (pixels[i + 3] > maxAlpha) maxAlpha = pixels[i + 3];
    if (pixels[i] > maxRed) maxRed = pixels[i];
    if (pixels[i + 2] > maxBlue) maxBlue = pixels[i + 2];
  }
  return [maxAlpha, maxRed, maxBlue];
}

void main() {
  test('整行高亮不继承正文透明度，也不残留正文红色边缘', () async {
    final stats = await _paintStats(_painter(
      line: LyricLine(start: Duration.zero, text: 'W'),
      highlightWidth: 0,
    ));
    expect(stats[0], 255);
    expect(stats[2], 255);
    expect(stats[1], 0);
  });

  test('未唱到的部分仍使用 activeStyle 的半透明色', () async {
    final stats = await _paintStats(_painter(
      line: LyricLine(
        start: Duration.zero,
        text: 'W',
        words: [
          LyricWord(text: 'W', start: Duration.zero),
        ],
      ),
      highlightWidth: 0,
    ));
    expect(stats[0], (_textColor.a * 255).round());
    expect(stats[1], greaterThan(0));
    expect(stats[2], 0);
  });

  test('高亮覆盖 y/p 下伸，墨水里不能有正文红', () async {
    final painter = _painter(
      line: LyricLine(start: Duration.zero, text: 'ypgqj'),
      highlightWidth: 0,
    );
    final recorder = ui.PictureRecorder();
    painter.paint(Canvas(recorder), _size);
    final image = await recorder
        .endRecording()
        .toImage(_size.width.toInt(), _size.height.toInt());
    final pixels = (await image.toByteData())!.buffer.asUint8List();
    var ink = 0;
    var maxRed = 0;
    var maxBlue = 0;
    for (var i = 0; i < pixels.length; i += 4) {
      if (pixels[i + 3] <= 16) continue;
      ink++;
      if (pixels[i] > maxRed) maxRed = pixels[i];
      if (pixels[i + 2] > maxBlue) maxBlue = pixels[i + 2];
    }
    expect(ink, greaterThan(0));
    expect(maxBlue, 255);
    expect(maxRed, 0);
  });
}
