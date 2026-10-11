import 'package:flutter/painting.dart';

// Capability selection happens once, outside the frame loop. Dynamic calls
// retain modern floating-point colors/native disposal without linking newer
// APIs when this library is compiled by Flutter 2 / Dart 2.12.
final Color Function(Color, double) colorWithOpacity = _opacityImplementation();
final double Function(Color) colorOpacity = _alphaImplementation();

final bool paintChangesNeedLayout = _detectPaintLayout();

bool _detectPaintLayout() {
  final painter = TextPainter(
      textDirection: TextDirection.ltr,
      text:
          const TextSpan(text: 'A', style: TextStyle(color: Color(0xFF000000))))
    ..layout();
  painter.text =
      const TextSpan(text: 'A', style: TextStyle(color: Color(0xFFFFFFFF)));
  try {
    // Older TextPainter versions invalidate geometry for a color-only change.
    return !painter.width.isFinite;
  } catch (_) {
    return true;
  } finally {
    disposeTextPainter(painter);
  }
}

Color Function(Color, double) _opacityImplementation() {
  try {
    (const Color(0xFFFFFFFF) as dynamic).withValues(alpha: 1.0);
    return (color, alpha) =>
        (color as dynamic).withValues(alpha: alpha) as Color;
  } on NoSuchMethodError {
    // ignore: deprecated_member_use
    return (color, alpha) => color.withOpacity(alpha);
  }
}

double Function(Color) _alphaImplementation() {
  try {
    final double alpha = (const Color(0xFFFFFFFF) as dynamic).a as double;
    assert(alpha == 1);
    return (color) => (color as dynamic).a as double;
  } on NoSuchMethodError {
    // ignore: deprecated_member_use
    return (color) => color.alpha / 255;
  }
}

final void Function(TextPainter) disposeTextPainter = _disposeImplementation();

void Function(TextPainter) _disposeImplementation() {
  final probe = TextPainter();
  try {
    (probe as dynamic).dispose();
    return (painter) => (painter as dynamic).dispose();
  } on NoSuchMethodError {
    // Old engines release paragraphs when Dart references are dropped.
    return (painter) {
      painter.text = null;
    };
  }
}
