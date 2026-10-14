import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import '../controller/lyric_controller.dart';
import '../model/lyric_gap.dart';
import '../preset/lyric_effects.dart';
import '../rendering/lyric_layout.dart';
import '../rendering/lyric_countdown_painter.dart';
import '../rendering/lyric_painter.dart';
import '../rendering/lyric_word_layout.dart';
import '../rendering/lyric_word_motion.dart';
import '../rendering/lyric_word_raster.dart';
import '../rendering/resolved_preset.dart';
import '../preset/lyric_preset.dart';
import '../view/lyric_details.dart';

/// All browsing state belongs to a single attachment, never to the controller.
class LyricViewSession extends ChangeNotifier {
  final wordRasterCache = LyricWordRasterCache();
  final LyricController controller;
  final Object viewId;
  final ScrollController scrollController = ScrollController();
  final ValueNotifier<int> presentation = _PresentationNotifier();
  late final LyricViewConnection connection;
  late final AnimationController _transition;
  late final AnimationController _focusAnimation;
  late final AnimationController _travel;
  late final AnimationController _wave;
  late final AnimationController _settle;
  late final Ticker _floatTicker;
  Duration _floatElapsed = Duration.zero;
  Duration _floatBaseElapsed = Duration.zero;
  final Map<int, LyricLineVisualState> _stateFrom = {};
  final Map<int, LyricLineVisualState> _frameStates = {};
  final Map<int, LyricLayout> _outgoing = {};
  int _previousActive = -1;
  bool _animateFollow = false;
  final Map<int, Duration> _exitPositions = {};
  final Map<int, double> _residual = {};
  double _focusFrom = 0;
  double _focusTo = 0;
  double _travelFrom = 0;
  double _travelTo = 0;
  LyricAnimation _travelSpec = const LyricAnimation(duration: Duration.zero);
  int _travelOrigin = 0;
  int _waveOrigin = 0;
  Completer<void>? _travelDone;
  bool reduceMotion = false;
  bool _enabled = true;
  ResolvedPreset? _style;
  LyricLayout? layout;
  ViewportOffset? _offset;
  Size size = Size.zero;
  bool needsLayout = true;
  bool following = true;
  bool dragging = false;
  bool scrolling = false;
  int? selectedIndex;
  int _active = -1;
  int _documentRevision = 0;
  bool _disposed = false;
  bool _replaceLayout = true;
  bool _pendingFollow = true;
  bool _presentationScheduled = false;
  bool _programmatic = false;
  Timer? _snapTimer;
  Timer? _resumeTimer;
  Completer<void>? _layoutReady;
  Duration _timeOffset = Duration.zero;
  Duration _lastPosition = Duration.zero;
  LyricGapTimeline? _gaps;
  LyricGap? _countdownGap;
  ValueChanged<LyricLineDetails>? onLineTap;
  ValueChanged<LyricLineDetails?>? onSelectionChanged;
  ValueChanged<bool>? onFollowChanged;

  LyricViewSession(
      {required this.controller,
      required this.viewId,
      required TickerProvider vsync}) {
    _transition = AnimationController(vsync: vsync, value: 1)
      ..addListener(_frame);
    _focusAnimation = AnimationController(vsync: vsync, value: 1)
      ..addListener(_repaint);
    _travel = AnimationController(vsync: vsync, value: 1)
      ..addListener(_travelTick);
    _wave = AnimationController(vsync: vsync, value: 1)..addListener(_frame);
    _settle = AnimationController(vsync: vsync, value: 1)..addListener(_frame);
    _floatTicker = vsync.createTicker((elapsed) {
      _floatElapsed = _floatBaseElapsed + elapsed;
      // Float changes pixels only, never playback, layout or selection UI.
      _repaint();
    });
    _travel.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _programmatic = false;
        final done = _travelDone;
        _travelDone = null;
        if (done != null && !done.isCompleted) done.complete();
      }
    });
    connection = LyricViewConnection(
        controller: controller,
        id: viewId,
        resume: resumeFollow,
        scroll: scrollToLine);
    _documentRevision = connection.documentRevision;
    _active = controller.activeLineIndex ?? -1;
    _focusFrom = _focusTo = math.max(0, _active).toDouble();
    _timeOffset = controller.timeOffset;
    _lastPosition = controller.effectivePosition;
    controller.addListener(_playbackChanged);
  }

  LyricPreset get preset => _style!.preset;
  double get devicePixelRatio => _style!.devicePixelRatio;
  int get activeIndex => _active;
  Duration positionFor(int index) => index == _active
      ? controller.effectivePosition
      : _exitPositions[index] ?? controller.effectivePosition;
  double get scrollY => _offset?.hasPixels == true ? _offset!.pixels : 0;
  bool get isEmpty =>
      !hasCountdown &&
      (controller.document?.lines.isNotEmpty != true ||
          (preset.displayMode == LyricDisplayMode.activeLine &&
              _active < 0 &&
              _outgoing.isEmpty));
  bool get hasCountdown => _countdownGap != null;

  LyricGap? _countdownAtPosition() {
    if (_style == null || !preset.countdown.enabled) return null;
    // Preserve the existing load path for views that do not opt in.
    return (_gaps ??= LyricGapTimeline(controller.document))
        .at(controller.effectivePosition, preset.countdown);
  }

  LyricCountdownFrame? get countdownFrame {
    final gap = _countdownGap;
    if (gap == null || size.isEmpty) return null;
    final config = preset.countdown;
    final current = layout;
    // A countdown is the row immediately before the next lyric. Share that
    // row's travel, wave and reflow offsets during both following and browsing.
    final y = activeOnly
        ? preset.activeAnchor.resolve(size.height) - config.height / 2
        : current == null
            ? null
            : lineTop(gap.nextIndex) +
                visualState(gap.nextIndex).offset.dy -
                current.countdownExtent;
    if (y == null) return null;
    return LyricCountdownFrame(
      nextIndex: gap.nextIndex,
      gapStart: gap.start,
      gapEnd: gap.end,
      displayStart: gap.displayStart(config),
      dotProgress: gap.dotProgress(controller.effectivePosition, config),
      position: controller.effectivePosition,
      isIntro: gap.isIntro,
      rect: Rect.fromLTWH(_style!.padding.left, y,
          math.max(0, size.width - _style!.padding.horizontal), config.height),
    );
  }

  LyricCountdownPainter? get countdownPainter {
    final frame = countdownFrame;
    return frame == null
        ? null
        : LyricCountdownPainter(_style!, frame,
            animate: !reduceMotion && _enabled);
  }

  bool get retainsOutgoing =>
      preset.lineTransition.resolver != null ||
      preset.lineTransition.state(false).opacity < 1;
  bool get activeOnly => preset.displayMode == LyricDisplayMode.activeLine;
  LyricLayout? layoutFor(int index) =>
      layout?.contains(index) == true ? layout : _outgoing[index];

  void configure(ResolvedPreset style,
      {bool enabled = true, bool disableAnimations = false}) {
    final old = _style;
    _style = style;
    if (old != null &&
        (style.devicePixelRatio != old.devicePixelRatio ||
            style.needsTextLayout(old) ||
            !style.sameTextPaint(old))) {
      wordRasterCache.clear();
    }
    _frameStates.clear();
    final value = style.preset;
    if ([
      value.selectionSnapDelay,
      value.lineTransition.enterDuration,
      value.lineTransition.exitDuration,
      value.lineMotion.delay,
      value.lineMotion.maxDelay,
      value.lineMotion.waveDuration,
      value.wordEffects.liftDuration,
      value.wordEffects.floatPeriod,
      value.wordEffects.floatStagger,
      value.countdown.breathDuration,
      if (value.resumeDelay != null) value.resumeDelay!
    ].any((d) => d.isNegative)) {
      throw ArgumentError('Lyric delays and durations must be non-negative.');
    }
    if (value.countdown.dotDuration <= Duration.zero) {
      throw ArgumentError('Countdown dotDuration must be positive.');
    }
    final gap = _countdownAtPosition();
    if (!identical(gap, _countdownGap)) {
      _countdownGap = gap;
      needsLayout = true;
      _pendingFollow = following;
    }
    final nextActive = hasCountdown ? -1 : controller.activeLineIndex ?? -1;
    if (_active != nextActive) {
      if (old == null) {
        _active = nextActive;
      } else {
        _retarget(active: nextActive);
      }
      needsLayout = true;
      _replaceLayout = _replaceLayout || activeOnly;
      _pendingFollow = following;
    }
    if (old == null) _focusFrom = _focusTo = _playbackFocus;
    final inactive = value.lineTransition.state(false);
    if (!inactive.offset.dx.isFinite ||
        !inactive.offset.dy.isFinite ||
        !inactive.scale.isFinite ||
        inactive.scale <= 0 ||
        !inactive.blurSigma.isFinite) {
      throw ArgumentError(
          'Composed line effects must have finite bounds and positive scale.');
    }
    final jump = value.jumpScrollThreshold;
    if (jump != null && (!jump.isFinite || jump < 0)) {
      throw ArgumentError(
          'jumpScrollThreshold must be finite and non-negative.');
    }
    final motionChanged =
        reduceMotion != disableAnimations || _enabled != enabled;
    reduceMotion = disableAnimations;
    _enabled = enabled;
    connection.enabled = enabled;
    if (motionChanged) {
      if (!enabled || reduceMotion) {
        _finishAnimations();
        if (following) _pendingFollow = needsLayout = true;
      }
      if (!enabled) {
        _cancelTimers();
      } else if (!following) {
        _scheduleIdle();
      }
    }
    if (old != null &&
        style.preset == old.preset &&
        (!style.needsTextLayout(old) &&
            style.sameTextPaint(old) &&
            style.padding == old.padding)) {
      _syncFloatTicker();
      return;
    }
    _replaceLayout = _replaceLayout ||
        old == null ||
        style.needsTextLayout(old) ||
        style.preset.displayMode != old.preset.displayMode;
    needsLayout = true;
    _cancelTimers();
    _finishAnimations();
    if (!value.interactive || activeOnly) {
      _setFollowing(true);
      _select(null);
    } else if (!following) {
      _scheduleIdle();
    }
    _pendingFollow = following;
    _syncFloatTicker();
    _repaint();
    _present();
  }

  void _frame() {
    _frameStates.clear();
    final complete = _transition.value == 1;
    final exitComplete = complete ||
        (_style != null &&
            _transition.value * (_transition.duration?.inMicroseconds ?? 0) >=
                preset.lineTransition.exitDuration.inMicroseconds);
    if (complete) {
      _stateFrom.clear();
      _exitPositions.clear();
    }
    if (exitComplete && _outgoing.isNotEmpty) {
      for (final entry in _outgoing.entries) {
        entry.value.dispose();
        _stateFrom.remove(entry.key);
        _exitPositions.remove(entry.key);
      }
      _outgoing.clear();
      _present();
    }
    _syncFloatTicker();
    _repaint();
    // Selection builders consume the same animated geometry as hit testing.
    if (!following) _present();
  }

  bool get characterFloatEnabled =>
      !reduceMotion &&
      _enabled &&
      preset.wordEffects.floatAmplitude > 0 &&
      preset.wordEffects.floatPeriod > Duration.zero &&
      (preset.wordEffects.floatMode == LyricFloatMode.all ||
          preset.highlight.enabled);

  bool _hasFloatingCharacters(int index) {
    if (activity(index) <= 0) return false;
    if (preset.wordEffects.floatMode == LyricFloatMode.all) return true;
    final line = layoutFor(index)?.wordLine(index, true);
    if (line == null) return false;
    return line.segments.isEmpty ||
        line.segments
            .any((segment) => segment.progress(positionFor(index)) > 0);
  }

  void _syncFloatTicker() {
    final running = !_disposed &&
        _style != null &&
        _offset != null &&
        characterFloatEnabled &&
        !isEmpty &&
        visibleIndices.any(_hasFloatingCharacters);
    if (running && !_floatTicker.isActive) {
      _floatBaseElapsed = _floatElapsed;
      _floatTicker.start();
    } else if (!running && _floatTicker.isActive) {
      _floatTicker.stop();
    }
  }

  double characterFloatLift(int line, int character,
      {LyricWordLine? wordLine}) {
    if (!characterFloatEnabled || activity(line) <= 0) return 0;
    var amount = 1.0;
    if (preset.wordEffects.floatMode == LyricFloatMode.highlighted) {
      final words = wordLine ?? layoutFor(line)?.wordLine(line, true);
      if (words == null || character >= words.characters.length) return 0;
      amount = words.segments.isEmpty
          ? 1
          : words.characters[character].highlightProgress(
              positionFor(line), preset.highlight.tailFadeWidth);
    }
    return preset.wordEffects.floatAmplitude *
        activity(line) *
        amount *
        lyricCharacterFloat(_floatElapsed, preset.wordEffects.floatPeriod,
            preset.wordEffects.floatStagger, character, line);
  }

  double wordPopLift(int line, LyricWordSegment segment) => reduceMotion
      ? 0
      : preset.wordEffects.lift *
          activity(line) *
          lyricWordPop(positionFor(line), segment.start,
              preset.wordEffects.liftDuration);

  double get transitionValue =>
      preset.lineTransition.enterCurve.transform(_transition.value);
  double activity(int index) => visualState(index).activity;
  double get focus =>
      _focusFrom +
      (_focusTo - _focusFrom) *
          preset.lineTransition.enterCurve.transform(_focusAnimation.value);

  LyricLineVisualState visualState(int index) =>
      _frameStates.putIfAbsent(index, () {
        final state = _resolveVisualState(index);
        if (!hasCountdown) return state;
        // Dots take focus immediately; preserve offsets for continuous reflow.
        final inactive = preset.lineTransition.state(false);
        return LyricLineVisualState(
          offset: state.offset,
          scale: inactive.scale,
          opacity: inactive.opacity,
          blurSigma: inactive.blurSigma,
          activity: 0,
        );
      });

  LyricLineVisualState _resolveVisualState(int index) {
    final transition = preset.lineTransition;
    final target = transition.state(index == _active);
    final from = _stateFrom[index];
    if (from == null || from == target || _transition.value == 1) {
      return target;
    }
    final entering = index == _active;
    final duration =
        entering ? transition.enterDuration : transition.exitDuration;
    final elapsed =
        _transition.value * (_transition.duration?.inMicroseconds ?? 0);
    final raw = duration == Duration.zero
        ? 1.0
        : (elapsed / duration.inMicroseconds).clamp(0.0, 1.0).toDouble();
    final progress = (entering ? transition.enterCurve : transition.exitCurve)
        .transform(raw);
    // Resolve exact endpoints ourselves, so custom output cannot break retargeting.
    if (raw == 0) return from;
    if (raw == 1) return target;
    // Other rows may need to settle a layout offset, but only rows whose
    // playback activity changes should run a custom entrance/exit path.
    final resolver =
        from.activity == target.activity ? null : transition.resolver;
    var result = resolver?.call(LyricLineTransitionContext(
            progress: progress,
            from: from,
            to: target,
            index: index,
            activeIndex: _active,
            previousActiveIndex: _previousActive,
            entering: entering,
            lineRect: baseRect(index),
            viewportSize: size)) ??
        LyricLineVisualState.lerp(from, target, progress);
    if (!result.offset.dx.isFinite ||
        !result.offset.dy.isFinite ||
        !result.scale.isFinite ||
        result.scale <= 0 ||
        !result.opacity.isFinite ||
        !result.blurSigma.isFinite ||
        !result.activity.isFinite) {
      throw ArgumentError(
          'A lyric transition must return a finite visual state with positive scale.');
    }
    final bound = math.max(transition.displacementBound, from.offset.distance);
    final distance = result.offset.distance;
    result = LyricLineVisualState(
        offset: distance > bound && distance > 0
            ? result.offset * (bound / distance)
            : result.offset,
        scale: result.scale
            .clamp(.0001, math.max(transition.scaleBound, from.scale))
            .toDouble(),
        opacity: result.opacity.clamp(0.0, 1.0).toDouble(),
        blurSigma: result.blurSigma
            .clamp(0.0, math.max(transition.blurBound, from.blurSigma))
            .toDouble(),
        activity: result.activity.clamp(0.0, 1.0).toDouble());
    return result;
  }

  void _retarget({int? active}) {
    final indices = <int>{
      ...visibleIndices,
      if (!activeOnly && _countdownGap != null) _countdownGap!.nextIndex,
      _active,
      if (active != null) active
    };
    final values = <int, LyricLineVisualState>{
      for (final i in indices)
        if (i >= 0 && layoutFor(i) != null) i: visualState(i)
    };
    final oldActive = _active;
    if (active != null) {
      _previousActive = _active;
      _active = active;
      if (!activeOnly && layout != null) {
        for (final i in values.keys.toList()) {
          final state = values[i]!;
          final current = layout!;
          var scale = state.scale;
          // Effect-based transitions carry their own scale. Measuring active
          // paragraphs here would eagerly shape every nearby inactive row.
          if (preset.lineTransition.legacyScale) {
            final oldHeight = current.metric(i).height;
            final activeHeight = current.metric(i).activeHeight;
            final before = i == oldActive ? activeHeight : oldHeight;
            final after = i == _active ? activeHeight : oldHeight;
            if (after > 0) scale *= before / after;
          }
          final dy =
              current.lineTop(i, oldActive) - current.lineTop(i, _active);
          values[i] = LyricLineVisualState(
              offset: state.offset + Offset(0, dy),
              scale: scale,
              opacity: state.opacity,
              blurSigma: state.blurSigma,
              activity: state.activity);
        }
      }
      // A newly allocated active-only entry begins at its inactive endpoint.
      if (_active >= 0 && !values.containsKey(_active)) {
        values[_active] = preset.lineTransition.state(false);
      }
    }
    _stateFrom
      ..clear()
      ..addAll(values);
    _frameStates.clear();
    _exitPositions.removeWhere((index, _) => !values.containsKey(index));
    final duration = _transitionDuration;
    if (reduceMotion ||
        !_enabled ||
        !preset.lineTransition.enabled ||
        duration == Duration.zero) {
      _transition.value = 1;
      _frame();
    } else {
      _transition.duration = duration;
      _transition.forward(from: 0);
    }
    _retargetFocus();
  }

  Duration get _transitionDuration => _active >= 0 &&
          preset.lineTransition.enterDuration >
              preset.lineTransition.exitDuration
      ? preset.lineTransition.enterDuration
      : preset.lineTransition.exitDuration;

  double get _playbackFocus => _countdownGap != null
      ? _countdownGap!.nextIndex - .5
      : math.max(0, _active).toDouble();

  void _retargetFocus() {
    final target = following
        ? _playbackFocus
        : selectedIndex?.toDouble() ?? _playbackFocus;
    if (_focusTo == target) return;
    _focusFrom = focus;
    _focusTo = target;
    // Browsing moves the blur focus without restarting playback transitions.
    final duration = _transitionDuration;
    if (reduceMotion ||
        !_enabled ||
        !preset.lineTransition.enabled ||
        duration == Duration.zero ||
        (preset.distanceBlur.maxSigma == 0 &&
            preset.lineTransition.blurBound == 0)) {
      _focusAnimation.value = 1;
    } else {
      _focusAnimation.duration = duration;
      _focusAnimation.forward(from: 0);
    }
  }

  void _finishAnimations() {
    _stopTravel();
    _transition.value = 1;
    _focusAnimation.value = 1;
    _wave.value = 1;
    _settle.value = 1;
    _stateFrom.clear();
    _frameStates.clear();
    _exitPositions.clear();
    _residual.clear();
    for (final value in _outgoing.values) {
      value.dispose();
    }
    _outgoing.clear();
  }

  void _stopTravel() {
    _travel.stop();
    _programmatic = false;
    final done = _travelDone;
    _travelDone = null;
    if (done != null && !done.isCompleted) done.complete();
  }

  double get _paintScaleBound => _stateFrom.values.fold<double>(
      preset.lineTransition.scaleBound,
      (extent, state) => math.max(extent, state.scale));

  double get paintMargin =>
      3 * preset.lineMotion.maxLag +
      3 * preset.lineMotion.waveAmplitude +
      preset.wordEffects.extent * _paintScaleBound +
      3 * preset.distanceBlur.maxSigma * _paintScaleBound +
      preset.lineTransition.displacementBound +
      3 * preset.lineTransition.blurBound * _paintScaleBound +
      (_paintScaleBound > 1
          ? math.max(size.height, layout?.maxNormalHeight ?? 0) *
              (_paintScaleBound - 1)
          : 0) +
      _stateFrom.values.fold<double>(
          0, (extent, state) => math.max(extent, state.offset.distance)) +
      4;

  Iterable<int> get visibleIndices sync* {
    if (activeOnly) {
      if (hasCountdown) return;
      yield* _outgoing.keys;
      if (layout?.contains(_active) == true) yield _active;
      return;
    }
    final current = layout;
    if (current == null || current.metrics.isEmpty) return;
    final margin = paintMargin;
    for (var i = current.lineAtOffset(scrollY - margin, _active);
        i < current.firstIndex + current.metrics.length;
        i++) {
      if (current.lineTop(i, _active) - scrollY > size.height + margin) {
        break;
      }
      yield i;
    }
  }

  double _delay(int index, int origin) => math
      .min((index - origin).abs() * preset.lineMotion.delay.inMicroseconds,
          preset.lineMotion.maxDelay.inMicroseconds)
      .toDouble();

  double _travelPosition(double delay) {
    final duration = _travelSpec.duration.inMicroseconds;
    if (duration <= 0) return _travelTo;
    final elapsed = _travel.value * (_travel.duration?.inMicroseconds ?? 0);
    final t = ((elapsed - delay) / duration).clamp(0.0, 1.0);
    return _travelFrom +
        (_travelTo - _travelFrom) * _travelSpec.curve.transform(t);
  }

  double displacement(int index) {
    var result = 0.0;
    if (_travelDone != null) {
      result += (scrollY - _travelPosition(_delay(index, _travelOrigin)))
          .clamp(-preset.lineMotion.maxLag, preset.lineMotion.maxLag);
    }
    result += (_residual[index] ?? 0) *
        (1 - Curves.easeOutCubic.transform(_settle.value));
    if (_wave.value < 1 && preset.lineMotion.waveDuration > Duration.zero) {
      final elapsed = _wave.value * (_wave.duration?.inMicroseconds ?? 0);
      final t = ((elapsed - _delay(index, _waveOrigin)) /
              preset.lineMotion.waveDuration.inMicroseconds)
          .clamp(0.0, 1.0);
      result += math.sin(t * math.pi * 2) *
          math.pow(1 - t, 2) *
          preset.lineMotion.waveAmplitude /
          (1 + (index - _waveOrigin).abs() * .12);
    }
    // Retargeted residuals must stay inside the finite culling margin even
    // when callers repeatedly seek with unusually long settling durations.
    final limit =
        2 * (preset.lineMotion.maxLag + preset.lineMotion.waveAmplitude);
    return result.clamp(-limit, limit);
  }

  void _captureMotion() {
    final positions = <int, double>{
      for (final i in {
        ...visibleIndices,
        if (!activeOnly && _countdownGap != null) _countdownGap!.nextIndex,
      })
        if (displacement(i).abs() > .0001) i: displacement(i)
    };
    _stopTravel();
    _wave.value = 1;
    _residual
      ..clear()
      ..addAll(positions);
    if (positions.isNotEmpty &&
        !reduceMotion &&
        _enabled &&
        preset.lineTransition.enterDuration > Duration.zero) {
      _settle.duration = preset.lineTransition.enterDuration;
      _settle.forward(from: 0);
    } else {
      _settle.value = 1;
    }
  }

  void _startWave(int index) {
    if (reduceMotion ||
        !_enabled ||
        preset.lineMotion.waveDuration == Duration.zero ||
        preset.lineMotion.waveAmplitude == 0) {
      return;
    }
    _waveOrigin = index;
    _wave.duration =
        preset.lineMotion.waveDuration + preset.lineMotion.maxDelay;
    _wave.forward(from: 0);
  }

  void _travelTick() {
    if (_disposed || _travelDone == null || !scrollController.hasClients) {
      return;
    }
    final position = scrollController.position;
    _frameStates.clear();
    final target = _travelPosition(0)
        .clamp(position.minScrollExtent, position.maxScrollExtent)
        .toDouble();
    // jumpTo cancels native ballistic motion. The programmatic flag prevents
    // the resulting scroll notifications from being interpreted as browsing.
    _programmatic = true;
    if (position.pixels != target) position.jumpTo(target);
    _frame();
  }

  void attachOffset(ViewportOffset offset) {
    if (identical(offset, _offset)) return;
    _offset?.removeListener(_scrolled);
    _offset = offset..addListener(_scrolled);
    needsLayout = true;
  }

  void detachOffset(ViewportOffset offset) {
    if (!identical(offset, _offset)) return;
    _offset?.removeListener(_scrolled);
    _offset = null;
    _syncFloatTicker();
  }

  @override
  void removeListener(VoidCallback listener) {
    if (!_disposed) super.removeListener(listener);
  }

  void fontsChanged() {
    wordRasterCache.clear();
    _replaceLayout = true;
    needsLayout = true;
    _pendingFollow = following;
    _repaint();
  }

  void layoutViewport(Size viewportSize) {
    if (!needsLayout && size == viewportSize) return;
    final style = _style!;
    final document = controller.document;
    final old = layout;
    final changedSize = size != viewportSize;
    if (changedSize) {
      wordRasterCache.clear();
      _finishAnimations();
    }
    final firstLayout = old == null;
    final rebuild = _replaceLayout ||
        old == null ||
        old.contentWidth !=
            math.max(0, viewportSize.width - style.padding.horizontal);
    final reflowTops =
        !activeOnly && !rebuild && !changedSize && _transition.value < 1
            ? <int, double>{
                for (final index in _stateFrom.keys)
                  if (old!.contains(index)) index: old.lineTop(index, _active),
              }
            : const <int, double>{};
    size = viewportSize;
    if (document == null ||
        document.lines.isEmpty ||
        (activeOnly && _active < 0)) {
      if (!_outgoing.containsValue(old)) old?.dispose();
      layout = null;
    } else if (rebuild) {
      if (!_outgoing.containsValue(old)) old?.dispose();
      layout = _outgoing.remove(_active) ??
          LyricLayout.compute(document, style, size,
              onlyIndex: preset.displayMode == LyricDisplayMode.activeLine
                  ? _active
                  : null);
    } else {
      layout = old!.restyle(style, size);
    }
    if (layout != null) {
      final rows = activeOnly || _countdownGap == null
          ? const <int>[]
          : [_countdownGap!.nextIndex];
      layout!.countdownIndices = rows;
      layout!.countdownExtent =
          rows.isEmpty ? 0 : preset.countdown.height + preset.countdown.spacing;
      // Insert/remove only the visible countdown's space. Let captured lyric
      // rows settle from their previous positions through the normal reflow.
      _stateFrom.updateAll((index, state) => LyricLineVisualState(
          offset: state.offset +
              Offset(
                  0,
                  reflowTops.containsKey(index)
                      ? reflowTops[index]! - layout!.lineTop(index, _active)
                      : 0),
          scale: state.scale,
          opacity: state.opacity,
          blurSigma: state.blurSigma,
          activity: state.activity));
    }
    _replaceLayout = false;
    needsLayout = false;
    final offset = _offset!;
    offset.applyViewportDimension(size.height);
    var min = 0.0;
    var max = 0.0;
    final current = layout;
    if (current != null && current.metrics.isNotEmpty) {
      final first = current.firstIndex;
      final last = first + current.metrics.length - 1;
      min = math.min(
          -style.padding.top,
          math.min(current.lineOffsetY(first, _active, preset.activeAnchor),
              current.lineOffsetY(first, _active, preset.selectionAnchor)));
      max = math.max(
          current.contentHeight(_active) - size.height + style.padding.bottom,
          math.max(current.lineOffsetY(last, _active, preset.activeAnchor),
              current.lineOffsetY(last, _active, preset.selectionAnchor)));
      max = math.max(min, max);
      if (current.countdownIndices.isNotEmpty) {
        min = math.min(
            min, _countdownOffset(current, current.countdownIndices.first));
      }
    }
    // Dimensions can change on a line switch. Correct only out-of-range pixels;
    // a regular following transition retains its old position for animation.
    var pixels = scrollY.clamp(min, max).toDouble();
    if (following &&
        (firstLayout || changedSize || !_animateFollow) &&
        (_pendingFollow || changedSize || firstLayout)) {
      pixels = current != null ? _followOffset(current) ?? min : min;
    }
    if (pixels != scrollY) {
      final correction = pixels - scrollY;
      if (hasCountdown &&
          following &&
          _animateFollow &&
          _transition.value < 1) {
        // A shorter active credit can shrink the native scroll range before
        // reflow finishes. Preserve every captured row's screen position when
        // Scrollable clamps the offset, then let its normal transition settle.
        _stateFrom.updateAll((index, state) => LyricLineVisualState(
            offset: state.offset + Offset(0, correction),
            scale: state.scale,
            opacity: state.opacity,
            blurSigma: state.blurSigma,
            activity: state.activity));
      }
      offset.correctBy(correction);
    }
    offset.applyContentDimensions(min, max);
    _updateSelection();
    if (_pendingFollow &&
        following &&
        current != null &&
        _followOffset(current) != null) {
      final animate = _animateFollow && !firstLayout && !changedSize;
      _pendingFollow = false;
      if (animate) {
        _afterFrame(() {
          if (following) _follow(true);
        });
      }
    } else {
      _pendingFollow = false;
    }
    _frameStates.clear();
    _syncFloatTicker();
    _present();
    final ready = _layoutReady;
    if (ready != null) {
      _afterFrame(() {
        if (!ready.isCompleted) ready.complete();
        if (identical(_layoutReady, ready)) _layoutReady = null;
      });
    }
  }

  void _playbackChanged() {
    if (_disposed) return;
    final previousPosition = _lastPosition;
    _lastPosition = controller.effectivePosition;
    final documentChanged = _documentRevision != connection.documentRevision;
    if (documentChanged) _gaps = null;
    final gap = _countdownAtPosition();
    final countdownChanged = !identical(gap, _countdownGap);
    _countdownGap = gap;
    final next = hasCountdown ? -1 : controller.activeLineIndex ?? -1;
    final activeChanged = next != _active;
    if (countdownChanged) needsLayout = true;
    if (_timeOffset != controller.timeOffset) {
      _timeOffset = controller.timeOffset;
      _present();
    }
    if (documentChanged) {
      wordRasterCache.clear();
      _documentRevision = connection.documentRevision;
      _cancelTimers();
      if (_style != null) _finishAnimations();
      _active = next;
      _select(null);
      _setFollowing(true);
      _focusFrom = _focusTo = _playbackFocus;
      _replaceLayout = true;
      needsLayout = true;
      _pendingFollow = true;
    } else if (activeChanged) {
      if (_style == null) {
        _active = next;
      } else {
        // Keep the outgoing word fill/lift at its last rendered time during a
        // seek; filling the old line completely would create a white flash.
        if (_active >= 0) _exitPositions[_active] = previousPosition;
        if (activeOnly && layout?.contains(_active) == true) {
          if (_active >= 0 &&
              retainsOutgoing &&
              preset.lineTransition.enabled &&
              preset.lineTransition.exitDuration > Duration.zero &&
              !reduceMotion &&
              _enabled) {
            _outgoing[_active]?.dispose();
            _outgoing[_active] = layout!;
          }
        }
        _retarget(active: next);
        if (activeOnly || preset.layoutMode == LyricLayoutMode.dualStyle) {
          needsLayout = true;
          _replaceLayout = activeOnly;
          _pendingFollow = following;
          _animateFollow = !activeOnly;
        }
        if (following && !needsLayout) {
          if (next >= 0) {
            _follow(true);
          } else if (scrollController.hasClients) {
            _moveTo(scrollController.position.minScrollExtent, true);
          }
        }
      }
      _present();
    }
    if (countdownChanged) {
      if (!documentChanged && !activeChanged && !activeOnly) _retarget();
      needsLayout = true;
      _pendingFollow = following;
      _animateFollow = !activeOnly && !documentChanged;
    }
    if (countdownChanged) _present();
    _syncFloatTicker();
    _repaint();
  }

  double get highlightWidth => highlightWidthFor(_active, true);

  double highlightWidthFor(int index, bool active) {
    final current = layoutFor(index);
    if (current == null ||
        !preset.highlight.enabled ||
        current.fixed ||
        preset.wordEffects.enabled) {
      return 0;
    }
    final words = current.metric(index).words ?? [];
    var width = 0.0;
    final time = positionFor(index);
    for (var i = 0; i < words.length; i++) {
      final word = words[i];
      if (time < word.word.start) continue;
      final end = word.word.end ?? word.word.start;
      var segment = active ? word.highlightWidth : word.width;
      if (i == words.length - 1 && end > word.word.start) {
        segment += preset.highlight.tailFadeWidth;
      }
      final duration = (end - word.word.start).inMicroseconds;
      width += segment *
          (duration <= 0
              ? 1
              : ((time - word.word.start).inMicroseconds / duration)
                  .clamp(0.0, 1.0));
    }
    return width;
  }

  LyricPainter? get painter => layout == null && _outgoing.isEmpty
      ? null
      : LyricPainter(
          layout: layout ?? _outgoing.values.first,
          playIndex: _active,
          scrollY: scrollY,
          activeHighlightWidth: highlightWidth,
          isSelecting: !following,
          selectedIndex: selectedIndex,
          session: this);

  void _scrolled() {
    if (_disposed) return;
    _frameStates.clear();
    _updateSelection();
    _syncFloatTicker();
    _repaint();
    if (!following) _present();
    if (dragging &&
        preset.selectionSnapMode == LyricSelectionSnapMode.onDragPause) {
      _scheduleSnap();
    }
  }

  void _updateSelection() {
    final current = layout;
    if (following || current == null || current.metrics.isEmpty) {
      _select(null);
      return;
    }
    _select(current.closestToAnchor(scrollY, _active, preset.selectionAnchor));
  }

  void _select(int? index) {
    if (selectedIndex == index) return;
    selectedIndex = index;
    if (_style != null) _retargetFocus();
    final details = index == null ? null : lineDetails(index);
    _emit(() => onSelectionChanged?.call(details));
    _present();
  }

  void _setFollowing(bool value) {
    if (following == value) return;
    following = value;
    if (_style != null) _retargetFocus();
    _emit(() => onFollowChanged?.call(value));
    _present();
  }

  void beginBrowsing({bool programmatic = false}) {
    if (_disposed ||
        (!preset.interactive && !programmatic) ||
        activeOnly ||
        isEmpty) {
      return;
    }
    _captureMotion();
    _pendingFollow = false;
    _cancelTimers();
    _setFollowing(false);
    _updateSelection();
    _repaint();
  }

  bool scrollNotification(ScrollNotification notification) {
    if (notification.depth != 0) return false;
    if (notification is ScrollStartNotification) {
      if (notification.dragDetails != null || !_programmatic) beginBrowsing();
      dragging = notification.dragDetails != null;
      scrolling = true;
    } else if (notification is ScrollUpdateNotification) {
      if (notification.dragDetails != null) dragging = true;
    } else if (notification is ScrollEndNotification) {
      dragging = false;
      scrolling = false;
      if (!_programmatic && !following) _scheduleIdle();
    } else if (notification is UserScrollNotification &&
        notification.direction == ScrollDirection.idle) {
      dragging = false;
    }
    if (!following) _present();
    return false;
  }

  void pointerSignal(PointerSignalEvent event) {
    if (event is PointerScrollEvent) {
      beginBrowsing();
      if (!following) _scheduleIdle();
    }
  }

  void _cancelTimers() {
    _snapTimer?.cancel();
    _resumeTimer?.cancel();
  }

  void _scheduleSnap() {
    _snapTimer?.cancel();
    if (!_enabled ||
        following ||
        preset.selectionSnapMode == LyricSelectionSnapMode.none) {
      return;
    }
    _snapTimer = Timer(preset.selectionSnapDelay, () {
      if (!_disposed && !following && selectedIndex != null) {
        final target = layout!
            .lineOffsetY(selectedIndex!, _active, preset.selectionAnchor);
        if (dragging && scrollController.hasClients) {
          // animateTo/jumpTo cancels Flutter's drag activity. Preserve the
          // current gesture so a paused finger can continue after snapping.
          final position = scrollController.position;
          final clamped = target
              .clamp(position.minScrollExtent, position.maxScrollExtent)
              .toDouble();
          position.correctBy(clamped - position.pixels);
          _updateSelection();
          _repaint();
          _present();
        } else {
          _moveTo(target, true);
        }
      }
    });
  }

  void _scheduleIdle() {
    _cancelTimers();
    if (following || !_enabled) return;
    _scheduleSnap();
    final delay = preset.resumeDelay;
    if (delay != null) {
      _resumeTimer = Timer(delay, () {
        resumeFollow(true);
      });
    }
  }

  Future<void> _moveTo(double target, bool animate, {int? origin}) async {
    if (_disposed || !scrollController.hasClients) return;
    _captureMotion();
    final position = scrollController.position;
    target = target
        .clamp(position.minScrollExtent, position.maxScrollExtent)
        .toDouble();
    final distance = (target - position.pixels).abs();
    final animation = preset.scrollAnimation.resolve(distance);
    if (animation.duration.isNegative) {
      throw ArgumentError('Scroll duration must be non-negative.');
    }
    _travelOrigin = origin ?? math.max(0, _active);
    // Traversing more than a viewport compresses distant rows into the same
    // short stagger. Jump instead, discarding the interrupted motion's lag.
    if (!animate ||
        reduceMotion ||
        !_enabled ||
        (preset.jumpScrollThreshold != null &&
            distance > size.height * preset.jumpScrollThreshold!) ||
        animation.duration == Duration.zero) {
      _residual.clear();
      _settle.value = 1;
      _programmatic = true;
      position.jumpTo(target);
      _programmatic = false;
      _frame();
      return;
    }
    _startWave(_travelOrigin);
    _travelFrom = position.pixels;
    _travelTo = target;
    _travelSpec = animation;
    _travel.duration = animation.duration + preset.lineMotion.maxDelay;
    final done = Completer<void>();
    _travelDone = done;
    _programmatic = true;
    // Completion is shared with cancellation through _travelDone.
    // ignore: unawaited_futures
    _travel.forward(from: 0);
    await done.future;
  }

  Future<void> _follow(bool animate, {int? origin}) async {
    final current = layout;
    final target = current == null ? null : _followOffset(current);
    if (target != null) {
      await _moveTo(target, animate,
          origin: origin ?? _countdownGap?.nextIndex);
    }
  }

  double _countdownOffset(LyricLayout current, int nextIndex) =>
      current.countdownTop(nextIndex, _active) +
      preset.lineTransition.state(false).offset.dy +
      preset.countdown.height / 2 -
      preset.activeAnchor.resolve(size.height);

  double? _followOffset(LyricLayout current) =>
      _countdownGap != null && !activeOnly
          ? _countdownOffset(current, _countdownGap!.nextIndex)
          : current.contains(_active)
              ? current.lineOffsetY(_active, _active, preset.activeAnchor)
              : null;

  Future<void> resumeFollow(bool animate, {int? origin}) async {
    if (_disposed) return;
    _cancelTimers();
    _setFollowing(true);
    _select(null);
    dragging = false;
    if (needsLayout) {
      _pendingFollow = true;
      _animateFollow = false;
      await _waitForLayout();
    } else {
      await _follow(animate, origin: origin);
    }
    _repaint();
  }

  Future<void> scrollToLine(int index, bool animate) async {
    if (_disposed) return;
    final revision = _documentRevision;
    if (_style == null || needsLayout) await _waitForLayout();
    if (_disposed || revision != _documentRevision || activeOnly) {
      return;
    }
    beginBrowsing(programmatic: true);
    final current = layout;
    if (current == null || index < 0 || index >= current.metrics.length) return;
    await _moveTo(
        current.lineOffsetY(index, _active, preset.selectionAnchor), animate,
        origin: index);
    if (!_disposed &&
        !following &&
        !dragging &&
        revision == _documentRevision) {
      _scheduleIdle();
    }
  }

  Future<void> _waitForLayout() {
    if (_disposed || !needsLayout) return Future<void>.value();
    _layoutReady ??= Completer<void>();
    return _layoutReady!.future;
  }

  LyricLineDetails lineDetails(int index) {
    final doc = controller.document!;
    final line = doc.lines[index];
    final position = line.start - doc.offset - controller.timeOffset;
    return LyricLineDetails(
        viewId: viewId,
        index: index,
        line: line,
        seekPosition: position < Duration.zero ? Duration.zero : position);
  }

  double scaleFor(int index) => visualState(index).scale;
  double contentX(double width) {
    final current = layout ?? _outgoing.values.first;
    switch (preset.contentAlignment) {
      case LyricContentAlignment.center:
        return (current.contentWidth - width) / 2;
      case LyricContentAlignment.start:
        return _style!.direction == TextDirection.ltr
            ? 0
            : current.contentWidth - width;
      case LyricContentAlignment.end:
        return _style!.direction == TextDirection.ltr
            ? current.contentWidth - width
            : 0;
    }
  }

  double get pivotX => contentX(0);
  bool paintsActive(int index) =>
      !hasCountdown && (index == _active || activeOnly);
  double lineTop(int index) {
    final current = layoutFor(index)!;
    return activeOnly
        ? preset.activeAnchor.resolve(size.height) -
            current.anchorOffsetY(index, true, preset.activeAnchor.target)
        : current.lineTop(index, _active) - scrollY + displacement(index);
  }

  Rect baseRect(int index) {
    final current = layoutFor(index);
    if (current == null) return Rect.zero;
    return Rect.fromLTWH(
        _style!.padding.left,
        lineTop(index),
        current.contentWidth,
        current.getLineHeight(paintsActive(index), index));
  }

  Rect contentRect(int index) => _transformRect(index, baseRect(index));
  Rect lineRect(int index) {
    final rect = baseRect(index);
    return _transformRect(
        index,
        preset.layoutMode == LyricLayoutMode.dualStyle
            ? Rect.fromLTWH(0, rect.top, size.width, rect.height)
            : rect);
  }

  Rect _transformRect(int index, Rect rect) {
    final state = visualState(index);
    return Rect.fromLTWH(
        (_style!.padding.left + pivotX) * (1 - state.scale) +
            rect.left * state.scale +
            state.offset.dx,
        rect.top + state.offset.dy,
        rect.width * state.scale,
        rect.height * state.scale);
  }

  double blurFor(int index) {
    final blur = preset.distanceBlur;
    final distance = !following && !blur.whenBrowsing
        ? 0.0
        : math.min(blur.maxSigma, (index - focus).abs() * blur.sigmaPerLine);
    // Keep the browsed row readable without moving playback highlighting or
    // replaying its line transition as selection crosses each row.
    final own = visualState(index).blurSigma *
        (following ? 1 : (index - focus).abs().clamp(0.0, 1.0));
    return math.sqrt(distance * distance + own * own);
  }

  LyricSelectionDetails? get selectionDetails {
    final index = selectedIndex;
    final current = layout;
    if (following ||
        index == null ||
        current == null ||
        index < 0 ||
        !current.contains(index)) {
      return null;
    }
    final rect = lineRect(index);
    final revision = _documentRevision;
    bool valid() =>
        !_disposed &&
        revision == _documentRevision &&
        selectedIndex == index &&
        !following;
    return LyricSelectionDetails(
        line: lineDetails(index),
        viewportSize: size,
        lineRect: rect,
        contentRect: contentRect(index),
        anchorY: preset.selectionAnchor.resolve(size.height),
        isActive: index == _active,
        isDragging: dragging,
        isSnapped:
            (current.lineOffsetY(index, _active, preset.selectionAnchor) -
                        scrollY)
                    .abs() <
                .5,
        onTap: onLineTap == null || !preset.interactive
            ? null
            : () {
                if (valid()) _tap(index);
              },
        resumeFollow: () {
          if (valid()) resumeFollow(true);
        });
  }

  void tapAt(Offset position) {
    if (!preset.interactive || (layout == null && _outgoing.isEmpty)) return;
    // Reverse painting order makes overlapping animated lines deterministic.
    for (final index in visibleIndices.toList().reversed) {
      if (visualState(index).opacity > 0 &&
          lineRect(index).contains(position)) {
        _tap(index);
        return;
      }
    }
  }

  void _tap(int index) {
    final callback = onLineTap;
    if (callback == null) return;
    final revision = _documentRevision;
    _captureMotion();
    _startWave(index);
    callback(lineDetails(index));
    if (!_disposed &&
        revision == connection.documentRevision &&
        preset.resumeOnTap) {
      resumeFollow(true, origin: index);
    }
  }

  void _repaint() {
    if (!_disposed) notifyListeners();
  }

  void _afterFrame(VoidCallback callback) {
    final SchedulerBinding? binding = SchedulerBinding.instance;
    binding!.addPostFrameCallback((_) {
      if (!_disposed) callback();
    });
  }

  void _emit(VoidCallback callback) {
    final SchedulerBinding? binding = SchedulerBinding.instance;
    if (binding!.schedulerPhase == SchedulerPhase.persistentCallbacks) {
      _afterFrame(callback);
    } else if (!_disposed) {
      callback();
    }
  }

  void _present() {
    if (_disposed || _presentationScheduled) return;
    final SchedulerBinding? binding = SchedulerBinding.instance;
    if (binding!.schedulerPhase == SchedulerPhase.persistentCallbacks) {
      _presentationScheduled = true;
      _afterFrame(() {
        _presentationScheduled = false;
        presentation.value++;
      });
    } else {
      presentation.value++;
    }
  }

  @override
  void dispose() {
    _disposed = true;
    wordRasterCache.clear();
    _cancelTimers();
    final ready = _layoutReady;
    _layoutReady = null;
    if (ready != null && !ready.isCompleted) ready.complete();
    _offset?.removeListener(_scrolled);
    controller.removeListener(_playbackChanged);
    connection.dispose();
    _stopTravel();
    _transition.dispose();
    _focusAnimation.dispose();
    _travel.dispose();
    _wave.dispose();
    _settle.dispose();
    _floatTicker.dispose();
    scrollController.dispose();
    for (final value in _outgoing.values) {
      value.dispose();
    }
    _outgoing.clear();
    layout?.dispose();
    layout = null;
    presentation.dispose();
    super.dispose();
  }
}

// Flutter 2 does not allow removing a listener after notifier disposal. A child
// builder may detach during didUpdateWidget after its old session was closed.
class _PresentationNotifier extends ValueNotifier<int> {
  bool _closed = false;
  _PresentationNotifier() : super(0);
  @override
  void removeListener(VoidCallback listener) {
    if (!_closed) super.removeListener(listener);
  }

  @override
  void dispose() {
    _closed = true;
    super.dispose();
  }
}
