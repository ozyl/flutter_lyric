import 'dart:math' as math;

import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

class LyricAnimationNotifier extends ChangeNotifier {
  LyricAnimationNotifier(TickerProvider vsync) {
    // 使用 Ticker 提供稳定 60/120Hz 刷新
    _ticker = vsync.createTicker(_onTick)..start();
  }

  Ticker? _ticker;
  double _elapsedMs = 0;

  // 记录字符触发的时间戳
  final Map<int, double> _triggerMap = {};
  int? _playIndex;

  void _onTick(Duration elapsed) {
    _elapsedMs = elapsed.inMilliseconds.toDouble();
    notifyListeners(); // 驱动重绘
  }

  void syncPlayIndex(int playIndex) {
    if (_playIndex != playIndex) {
      _playIndex = playIndex;
      reset();
    }
  }

  /// 这里的逻辑优化：增加一个微小的触发偏移，让动画更有预判感
  void checkAndTrigger(int charIndex, double highlightX, double charLeftX) {
    // 当扫描线接近字符（提前 5 像素）时触发，产生流畅感
    if (highlightX >= (charLeftX - 5) && !_triggerMap.containsKey(charIndex)) {
      _triggerMap[charIndex] = _elapsedMs;
    }
  }

  double getOffsetForChar(int charIndex, double maxUp) {
    final startTime = _triggerMap[charIndex];
    if (startTime == null) return 0;

    // 关键：时长增加到 300-400ms 更有波浪感
    const double duration = 350.0;
    final delta = _elapsedMs - startTime;

    if (delta >= duration || delta <= 0) return 0;

    final t = delta / duration;

    // 核心物理公式：sin(t * π) 实现 0 -> 1 -> 0 的起伏
    // 配合 pow(t, 0.7) 让起跳更快，落地更慢（轻盈感）
    double curve = math.sin(math.pow(t, 0.7) * math.pi);

    return -maxUp * curve;
  }

  void reset() {
    _triggerMap.clear();
  }

  @override
  void dispose() {
    _ticker?.dispose();
    super.dispose();
  }
}
