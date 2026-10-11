import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_lyric/src/rendering/lyric_layout.dart';
import 'package:flutter_lyric/src/rendering/lyric_painter.dart';
import 'package:flutter_lyric/src/rendering/line_transition.dart';

class BenchmarkPaintState {
  final ValueListenable<int> playIndex;
  final ValueListenable<double> scrollY;
  final ValueListenable<double> activeHighlightWidth;
  final ValueListenable<bool> isSelecting;
  final ValueListenable<LyricLineSwitchState> switchState;
  late final Listenable repaint = Listenable.merge(
      [playIndex, scrollY, activeHighlightWidth, isSelecting, switchState]);
  BenchmarkPaintState(
      {required this.playIndex,
      required this.scrollY,
      required this.activeHighlightWidth,
      required this.isSelecting,
      required this.switchState});
}

class BenchmarkPainter extends CustomPainter {
  final LyricLayout layout;
  final BenchmarkPaintState state;
  BenchmarkPainter({required this.layout, required this.state})
      : super(repaint: state.repaint);
  @override
  void paint(Canvas canvas, Size size) => LyricPainter(
          layout: layout,
          playIndex: state.playIndex.value,
          scrollY: state.scrollY.value,
          activeHighlightWidth: state.activeHighlightWidth.value,
          isSelecting: state.isSelecting.value,
          switchState: state.switchState.value)
      .paint(canvas, size);
  @override
  bool shouldRepaint(BenchmarkPainter old) =>
      old.layout != layout || old.state != state;
}

void disposeNative(dynamic resource) {
  try {
    resource.dispose();
  } on NoSuchMethodError {/* Old engine GC. */}
}
