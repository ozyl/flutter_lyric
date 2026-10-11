// From example/: flutter run -d macos --profile \
//   -t ../test/benchmarks/lyric_frame_benchmark.dart
// Reports engine frame timings without screenshots/readback. Keep the window
// visible. Each case warms up for 90 frames, then measures 240 animated frames.
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_lyric/core/lyric_model.dart';
import 'package:flutter_lyric/core/lyric_style.dart';
import 'package:flutter_lyric/core/lyric_styles.dart';
import 'package:flutter_lyric/render/lyric_layout.dart';
import 'package:flutter_lyric/render/lyric_painter.dart';
import 'package:flutter_lyric/widgets/mixins/lyric_line_switch_mixin.dart';
import 'package:flutter_lyric/widgets/mixins/lyric_mask_mixin.dart';

void main() => runApp(const MaterialApp(home: _Benchmark()));

class _Benchmark extends StatefulWidget {
  const _Benchmark();
  @override
  State<_Benchmark> createState() => _BenchmarkState();
}

class _BenchmarkState extends State<_Benchmark>
    with SingleTickerProviderStateMixin, LyricMaskMixin {
  static const _size = Size(400, 600);
  late final Ticker _ticker;
  late LyricLayout _layout;
  final _play = ValueNotifier(500);
  final _scroll = ValueNotifier(0.0);
  final _width = ValueNotifier(0.0);
  final _selecting = ValueNotifier(false);
  final _switching = ValueNotifier(LyricLineSwitchState(
    enterIndex: -1,
    exitIndex: -1,
    enterAnimationValue: 1,
    exitAnimationValue: 1,
  ));
  late final _state = LyricPaintState(
      playIndex: _play,
      scrollY: _scroll,
      activeHighlightWidth: _width,
      switchState: _switching,
      isSelecting: _selecting);
  int _case = 0;
  int _frame = 0;
  int? _start;
  int? _end;
  final _timings = <ui.FrameTiming>[];
  @override
  late LyricStyle style;
  @override
  Size get lyricSize => _size;

  @override
  void initState() {
    super.initState();
    _configure();
    SchedulerBinding.instance.addTimingsCallback(_onTimings);
    _ticker = createTicker(_tick)..start();
  }

  void _configure() {
    style = LyricStyles.default2.copyWith(
      enableSwitchAnimation: false,
      activeHighlightGradient:
          _case ~/ 2 == 1 ? LyricStyles.default2.activeHighlightGradient : null,
      fadeRange:
          FadeRange(top: _case.isOdd ? 80 : 0, bottom: _case.isOdd ? 80 : 0),
    );
    _layout = LyricLayout.compute(
        LyricModel(
            lines: List.generate(1000, (i) {
          final text = 'A scrolling lyric with wrapped words $i';
          return LyricLine(
              start: Duration(seconds: i),
              text: text,
              translation: 'Translation for line $i',
              words: [
                LyricWord(
                    text: text,
                    start: Duration.zero,
                    end: const Duration(seconds: 1)),
              ]);
        })),
        style,
        _size);
    _frame = 0;
    _start = null;
    _end = null;
    _timings.clear();
  }

  void _tick(Duration elapsed) {
    if (_end != null) return;
    final timestamp =
        SchedulerBinding.instance.currentSystemFrameTimeStamp.inMicroseconds;
    if (_frame == 90) _start = timestamp;
    if (_frame == 330) {
      _end = timestamp;
      return;
    }
    _play.value = 100 + (_frame ~/ 30 * 71) % 800;
    _scroll.value =
        _layout.lineTop(_play.value, _play.value) - 250 + _frame % 30 * 3.35;
    _width.value = 20 + _frame % 30 * 12.35;
    _selecting.value = _frame % 60 < 30;
    _frame++;
  }

  void _onTimings(List<ui.FrameTiming> values) {
    if (_start == null) return;
    _timings.addAll(values.where((t) =>
        t.timestampInMicroseconds(ui.FramePhase.vsyncStart) >= _start! &&
        (_end == null ||
            t.timestampInMicroseconds(ui.FramePhase.vsyncStart) < _end!)));
    if (_end == null ||
        values.last.timestampInMicroseconds(ui.FramePhase.vsyncStart) < _end!) {
      return;
    }
    String report(Iterable<Duration> durations) {
      final ms = durations.map((d) => d.inMicroseconds / 1000).toList()..sort();
      if (ms.isEmpty) return 'no samples';
      return 'p50=${ms[ms.length ~/ 2].toStringAsFixed(3)} '
          'p90=${ms[(ms.length * .9).floor()].toStringAsFixed(3)} '
          'p99=${ms[(ms.length * .99).floor()].toStringAsFixed(3)} ms';
    }

    // ignore: avoid_print
    print(
        'COMPOSITING highlight=${_case ~/ 2 == 1} fade=${_case.isOdd ? 80 : 0} '
        'n=${_timings.length} build ${report(_timings.map((t) => t.buildDuration))}; '
        'raster ${report(_timings.map((t) => t.rasterDuration))}; '
        'total ${report(_timings.map((t) => t.totalSpan))}');
    _case++;
    if (_case == 4) {
      _ticker.stop();
      SchedulerBinding.instance.removeTimingsCallback(_onTimings);
      // ignore: avoid_print
      print('COMPOSITING done');
      return;
    }
    setState(() {
      _layout.dispose();
      _configure();
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: const Color(0xFF182332),
        body: Center(
            child: SizedBox.fromSize(
          size: _size,
          child: RepaintBoundary(
              child: wrapMaskIfNeed(CustomPaint(
            size: _size,
            painter: LyricPainter.listenable(
                layout: _layout,
                state: _state,
                onAnchorIndexChange: (_) {},
                onShowLineRectsChange: (_) {},
                style: style),
          ))),
        )),
      );

  @override
  void dispose() {
    SchedulerBinding.instance.removeTimingsCallback(_onTimings);
    _ticker.dispose();
    _layout.dispose();
    _play.dispose();
    _scroll.dispose();
    _width.dispose();
    _selecting.dispose();
    _switching.dispose();
    super.dispose();
  }
}
