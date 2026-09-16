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
  Size size = _size,
  LyricStyle? style,
}) {
  final usedStyle = style ?? _style;
  return LyricPainter(
    layout: LyricLayout.compute(
      LyricModel(lines: [line]),
      usedStyle,
      size,
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
    style: usedStyle,
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

  test('逐字高亮的已唱部分不继承正文透明度', () async {
    final stats = await _paintStats(_painter(
      line: LyricLine(
        start: Duration.zero,
        text: 'WW',
        words: [
          LyricWord(text: 'W', start: Duration.zero),
          LyricWord(text: 'W', start: const Duration(seconds: 1)),
        ],
      ),
      highlightWidth: 80,
    ));
    expect(stats[0], 255);
    expect(stats[2], 255);
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

  test('折行后第二行的 g 也被高亮覆盖', () async {
    const size = Size(90, 240);
    final style = LyricStyles.default1.copyWith(
      textStyle: const TextStyle(fontSize: 28, height: 1.2, color: _textColor),
      activeStyle: const TextStyle(fontSize: 28, height: 1.2, color: _textColor),
      contentPadding: EdgeInsets.zero,
      activeHighlightColor: _highlightColor,
      enableSwitchAnimation: false,
    );
    final painter = _painter(
      line: LyricLine(start: Duration.zero, text: 'going going'),
      highlightWidth: 0,
      size: size,
      style: style,
    );
    expect(painter.layout.metrics.first.activeMetrics.length, greaterThan(1));

    final recorder = ui.PictureRecorder();
    painter.paint(Canvas(recorder), size);
    final image = await recorder
        .endRecording()
        .toImage(size.width.toInt(), size.height.toInt());
    final pixels = (await image.toByteData())!.buffer.asUint8List();
    var ink = 0;
    var maxRed = 0;
    for (var i = 0; i < pixels.length; i += 4) {
      if (pixels[i + 3] <= 16) continue;
      ink++;
      if (pixels[i] > maxRed) maxRed = pixels[i];
    }
    expect(ink, greaterThan(0));
    expect(maxRed, 0);
  });

  test('高亮渐变按行宽映射，左侧偏红右侧偏蓝', () async {
    final style = LyricStyles.default1.copyWith(
      textStyle: const TextStyle(fontSize: 40, color: _textColor),
      activeStyle: const TextStyle(fontSize: 40, color: _textColor),
      contentPadding: EdgeInsets.zero,
      activeHighlightColor: null,
      activeHighlightGradient: const LinearGradient(
        colors: [Color(0xFFFF0000), Color(0xFF0000FF)],
      ),
      enableSwitchAnimation: false,
    );
    final painter = _painter(
      line: LyricLine(start: Duration.zero, text: 'WWWWWW'),
      highlightWidth: 0,
      style: style,
    );
    final recorder = ui.PictureRecorder();
    painter.paint(Canvas(recorder), _size);
    final image = await recorder
        .endRecording()
        .toImage(_size.width.toInt(), _size.height.toInt());
    final pixels = (await image.toByteData())!.buffer.asUint8List();
    final width = _size.width.toInt();
    var leftRed = 0, leftBlue = 0, rightRed = 0, rightBlue = 0;
    var minX = width, maxX = 0;
    for (var y = 0; y < _size.height.toInt(); y++) {
      for (var x = 0; x < width; x++) {
        final i = (y * width + x) * 4;
        if (pixels[i + 3] <= 16) continue;
        if (x < minX) minX = x;
        if (x > maxX) maxX = x;
      }
    }
    expect(maxX - minX, greaterThan(20));
    final mid = (minX + maxX) / 2;
    for (var y = 0; y < _size.height.toInt(); y++) {
      for (var x = 0; x < width; x++) {
        final i = (y * width + x) * 4;
        if (pixels[i + 3] <= 16) continue;
        if (x < mid) {
          if (pixels[i] > leftRed) leftRed = pixels[i];
          if (pixels[i + 2] > leftBlue) leftBlue = pixels[i + 2];
        } else {
          if (pixels[i] > rightRed) rightRed = pixels[i];
          if (pixels[i + 2] > rightBlue) rightBlue = pixels[i + 2];
        }
      }
    }
    expect(leftRed, greaterThan(leftBlue));
    expect(rightBlue, greaterThan(rightRed));
  });

  test('折行后每行渐变都从该行左侧重新开始', () async {
    const size = Size(100, 280);
    final style = LyricStyles.default1.copyWith(
      textStyle: const TextStyle(fontSize: 32, height: 1.2, color: _textColor),
      activeStyle: const TextStyle(fontSize: 32, height: 1.2, color: _textColor),
      contentPadding: EdgeInsets.zero,
      activeHighlightColor: null,
      activeHighlightGradient: const LinearGradient(
        colors: [Color(0xFFFF0000), Color(0xFF0000FF)],
      ),
      enableSwitchAnimation: false,
    );
    final painter = _painter(
      line: LyricLine(start: Duration.zero, text: 'AAAA BBBB'),
      highlightWidth: 0,
      size: size,
      style: style,
    );
    expect(painter.layout.metrics.first.activeMetrics.length, greaterThan(1));

    final recorder = ui.PictureRecorder();
    painter.paint(Canvas(recorder), size);
    final image = await recorder
        .endRecording()
        .toImage(size.width.toInt(), size.height.toInt());
    final pixels = (await image.toByteData())!.buffer.asUint8List();
    final width = size.width.toInt();
    final height = size.height.toInt();
    final splitY = (painter.layout.metrics.first.activeMetrics[1].baseline -
            painter.layout.metrics.first.activeMetrics[1].ascent)
        .floor();

    int leftColor(int y0, int y1) {
      var maxRed = 0, maxBlue = 0, minX = width;
      for (var y = y0; y < y1 && y < height; y++) {
        if (y < 0) continue;
        for (var x = 0; x < width; x++) {
          final i = (y * width + x) * 4;
          if (pixels[i + 3] <= 16) continue;
          if (x < minX) minX = x;
        }
      }
      for (var y = y0; y < y1 && y < height; y++) {
        if (y < 0) continue;
        for (var x = minX; x < minX + 8 && x < width; x++) {
          final i = (y * width + x) * 4;
          if (pixels[i + 3] <= 16) continue;
          if (pixels[i] > maxRed) maxRed = pixels[i];
          if (pixels[i + 2] > maxBlue) maxBlue = pixels[i + 2];
        }
      }
      return maxRed - maxBlue;
    }

    expect(leftColor(0, splitY), greaterThan(0));
    expect(leftColor(splitY, height), greaterThan(0));
  });
}
