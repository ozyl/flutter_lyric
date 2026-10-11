import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import '../controller/lyric_controller.dart';
import '../preset/lyric_effects.dart';
import '../preset/lyric_preset.dart';
import '../rendering/line_transition.dart';
import '../rendering/lyric_layout.dart';
import '../rendering/lyric_painter.dart';
import '../rendering/resolved_preset.dart';
import 'lyric_details.dart';

/// All browsing state belongs to a single attachment, never to the controller.
class LyricViewSession extends ChangeNotifier {
  final LyricController controller;
  final Object viewId;
  final ScrollController scrollController = ScrollController();
  final ValueNotifier<int> presentation = _PresentationNotifier();
  late final LyricViewConnection connection;
  late final AnimationController _enter;
  late final AnimationController _exit;
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
  int _previousActive = -1;
  int _documentRevision = 0;
  bool _disposed = false;
  bool _replaceLayout = true;
  bool _pendingFollow = true;
  bool _animateFollow = false;
  bool _presentationScheduled = false;
  int _motion = 0;
  bool _programmatic = false;
  Timer? _snapTimer;
  Timer? _resumeTimer;
  Completer<void>? _layoutReady;
  Duration _timeOffset = Duration.zero;
  ValueChanged<LyricLineDetails>? onLineTap;
  ValueChanged<LyricLineDetails?>? onSelectionChanged;
  ValueChanged<bool>? onFollowChanged;

  LyricViewSession(
      {required this.controller,
      required this.viewId,
      required TickerProvider vsync}) {
    _enter = AnimationController(vsync: vsync, value: 1)..addListener(_repaint);
    _exit = AnimationController(vsync: vsync, value: 1)..addListener(_repaint);
    connection = LyricViewConnection(
        controller: controller,
        id: viewId,
        resume: resumeFollow,
        scroll: scrollToLine);
    _documentRevision = connection.documentRevision;
    _active = controller.activeLineIndex ?? -1;
    _timeOffset = controller.timeOffset;
    controller.addListener(_playbackChanged);
  }

  LyricPreset get preset => _style!.preset;
  int get activeIndex => _active;
  double get scrollY => _offset?.hasPixels == true ? _offset!.pixels : 0;
  bool get isEmpty =>
      controller.document?.lines.isNotEmpty != true ||
      (preset.displayMode == LyricDisplayMode.activeLine && _active < 0);

  void configure(ResolvedPreset style) {
    final old = _style;
    _style = style;
    if (style.preset.selectionSnapDelay.isNegative ||
        (style.preset.resumeDelay?.isNegative ?? false) ||
        style.preset.lineTransition.enterDuration.isNegative ||
        style.preset.lineTransition.exitDuration.isNegative) {
      throw ArgumentError(
          'Lyric delays and transition durations must be non-negative.');
    }
    if (old != null &&
        style.preset == old.preset &&
        style.padding == old.padding &&
        !style.needsTextLayout(old) &&
        style.sameTextPaint(old)) return;
    _replaceLayout = _replaceLayout ||
        old == null ||
        style.needsTextLayout(old) ||
        style.preset.displayMode != old.preset.displayMode;
    needsLayout = true;
    if (old == null || style.preset != old.preset) {
      _cancelTimers();
      _stopTransition();
      if (!preset.interactive ||
          preset.displayMode == LyricDisplayMode.activeLine) {
        _setFollowing(true);
        _select(null);
      } else if (!following) {
        _scheduleIdle();
      }
    }
    _pendingFollow = following;
    _animateFollow = false;
    _repaint();
    _present();
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
  }

  @override
  void removeListener(VoidCallback listener) {
    if (!_disposed) super.removeListener(listener);
  }

  void fontsChanged() {
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
    final firstLayout = old == null;
    final rebuild = _replaceLayout ||
        old == null ||
        old.contentWidth !=
            math.max(0, viewportSize.width - style.padding.horizontal);
    size = viewportSize;
    if (isEmpty || document == null) {
      old?.dispose();
      layout = null;
    } else if (rebuild) {
      old?.dispose();
      layout = LyricLayout.compute(document, style, size,
          onlyIndex: preset.displayMode == LyricDisplayMode.activeLine
              ? _active
              : null);
    } else {
      layout = old!.restyle(style, size);
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
    }
    // Dimensions can change on a line switch. Correct only out-of-range pixels;
    // a regular following transition retains its old position for animation.
    var pixels = scrollY.clamp(min, max).toDouble();
    if (following &&
        (firstLayout || changedSize || !_animateFollow) &&
        (_pendingFollow || changedSize || firstLayout)) {
      pixels = current != null && current.contains(_active)
          ? current.lineOffsetY(_active, _active, preset.activeAnchor)
          : min;
    }
    if (pixels != scrollY) offset.correctBy(pixels - scrollY);
    offset.applyContentDimensions(min, max);
    _updateSelection();
    if (_pendingFollow &&
        following &&
        current != null &&
        current.contains(_active)) {
      final animate = _animateFollow && !firstLayout && !changedSize;
      _pendingFollow = false;
      if (animate)
        _afterFrame(() {
          if (following) _follow(true);
        });
    } else {
      _pendingFollow = false;
    }
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
    final next = controller.activeLineIndex ?? -1;
    final documentChanged = _documentRevision != connection.documentRevision;
    if (_timeOffset != controller.timeOffset) {
      _timeOffset = controller.timeOffset;
      _present();
    }
    if (documentChanged) {
      _documentRevision = connection.documentRevision;
      _cancelTimers();
      _motion++;
      _programmatic = false;
      _select(null);
      _setFollowing(true);
      _replaceLayout = true;
      needsLayout = true;
      _pendingFollow = true;
      _animateFollow = false;
      _stopTransition();
    }
    if (next != _active) {
      _previousActive = _active;
      _active = next;
      needsLayout = true;
      if (_style != null && preset.displayMode == LyricDisplayMode.activeLine)
        _replaceLayout = true;
      _pendingFollow = following;
      _animateFollow = !documentChanged;
      if (!documentChanged) _startTransition();
      _present();
    }
    // Word progress is sampled directly during painting, without widget builds.
    _repaint();
  }

  void _startTransition() {
    if (_style == null || !preset.lineTransition.enabled) {
      _stopTransition();
      return;
    }
    final transition = preset.lineTransition;
    _enter.duration = transition.enterDuration;
    _exit.duration = transition.exitDuration;
    if (_active < 0 || transition.enterDuration == Duration.zero) {
      _enter.value = 1;
    } else {
      _enter.forward(from: 0);
    }
    if (_previousActive < 0 || transition.exitDuration == Duration.zero) {
      _exit.value = 1;
    } else {
      _exit.forward(from: 0);
    }
  }

  void _stopTransition() {
    _previousActive = -1;
    _enter.value = 1;
    _exit.value = 1;
  }

  double get highlightWidth {
    final current = layout;
    if (current == null ||
        !current.contains(_active) ||
        !preset.highlight.enabled) return 0;
    final words = current.metric(_active).words ?? [];
    var width = 0.0;
    final time = controller.effectivePosition;
    for (var i = 0; i < words.length; i++) {
      final word = words[i];
      if (time < word.word.start) continue;
      final end = word.word.end ?? word.word.start;
      var segment = word.highlightWidth;
      if (i == words.length - 1 && end > word.word.start)
        segment += preset.highlight.tailFadeWidth;
      final duration = (end - word.word.start).inMicroseconds;
      width += segment *
          (duration <= 0
              ? 1
              : ((time - word.word.start).inMicroseconds / duration)
                  .clamp(0.0, 1.0));
    }
    return width;
  }

  LyricPainter? get painter {
    final current = layout;
    if (current == null) return null;
    final transition = preset.lineTransition;
    return LyricPainter(
        layout: current,
        playIndex: _active,
        scrollY: scrollY,
        activeHighlightWidth: highlightWidth,
        isSelecting: !following,
        selectedIndex: selectedIndex,
        switchState: LyricLineSwitchState(
            enterIndex: _active,
            exitIndex: _previousActive,
            enterAnimationValue: transition.enterCurve.transform(_enter.value),
            exitAnimationValue: transition.exitCurve.transform(_exit.value)));
  }

  void _scrolled() {
    if (_disposed) return;
    _updateSelection();
    _repaint();
    if (!following) _present();
    if (dragging &&
        preset.selectionSnapMode == LyricSelectionSnapMode.onDragPause)
      _scheduleSnap();
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
    final details = index == null ? null : lineDetails(index);
    _emit(() => onSelectionChanged?.call(details));
    _present();
  }

  void _setFollowing(bool value) {
    if (following == value) return;
    following = value;
    _emit(() => onFollowChanged?.call(value));
    _present();
  }

  void beginBrowsing({bool programmatic = false}) {
    if (_disposed ||
        (!preset.interactive && !programmatic) ||
        preset.displayMode == LyricDisplayMode.activeLine ||
        isEmpty) return;
    _motion++;
    _programmatic = false;
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
    if (following || preset.selectionSnapMode == LyricSelectionSnapMode.none)
      return;
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
    if (following) return;
    _scheduleSnap();
    final delay = preset.resumeDelay;
    if (delay != null)
      _resumeTimer = Timer(delay, () {
        resumeFollow(true);
      });
  }

  Future<void> _moveTo(double target, bool animate) async {
    if (_disposed || !scrollController.hasClients) return;
    final token = ++_motion;
    _programmatic = true;
    final position = scrollController.position;
    target = target
        .clamp(position.minScrollExtent, position.maxScrollExtent)
        .toDouble();
    final animation =
        preset.scrollAnimation.resolve((target - position.pixels).abs());
    if (animate &&
        animation.duration > Duration.zero &&
        target != position.pixels) {
      await position.animateTo(target,
          duration: animation.duration, curve: animation.curve);
    } else {
      position.jumpTo(target);
    }
    if (!_disposed && token == _motion) {
      _programmatic = false;
      _present();
    }
  }

  Future<void> _follow(bool animate) async {
    final current = layout;
    if (current != null && current.contains(_active)) {
      await _moveTo(
          current.lineOffsetY(_active, _active, preset.activeAnchor), animate);
    }
  }

  Future<void> resumeFollow(bool animate) async {
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
      await _follow(animate);
    }
    _repaint();
  }

  Future<void> scrollToLine(int index, bool animate) async {
    if (_disposed) return;
    final revision = _documentRevision;
    if (_style == null || needsLayout) await _waitForLayout();
    if (_disposed ||
        revision != _documentRevision ||
        preset.displayMode == LyricDisplayMode.activeLine) return;
    beginBrowsing(programmatic: true);
    final current = layout;
    if (current == null || !current.contains(index)) return;
    await _moveTo(
        current.lineOffsetY(index, _active, preset.selectionAnchor), animate);
    if (!_disposed && !following) _scheduleIdle();
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

  Rect lineRect(int index) => Rect.fromLTWH(
      0,
      layout!.lineTop(index, _active) - scrollY,
      size.width,
      layout!.getLineHeight(index == _active, index));

  LyricSelectionDetails? get selectionDetails {
    final index = selectedIndex;
    final current = layout;
    if (following ||
        index == null ||
        current == null ||
        !current.contains(index)) return null;
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
        contentRect: Rect.fromLTWH(
            _style!.padding.left, rect.top, current.contentWidth, rect.height),
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
    if (!preset.interactive || layout == null) return;
    final index = layout!.lineAtOffset(position.dy + scrollY, _active);
    if (layout!.contains(index) && lineRect(index).contains(position))
      _tap(index);
  }

  void _tap(int index) {
    final callback = onLineTap;
    if (callback == null) return;
    callback(lineDetails(index));
    if (!_disposed && preset.resumeOnTap) resumeFollow(true);
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
    if (binding!.schedulerPhase == SchedulerPhase.persistentCallbacks)
      _afterFrame(callback);
    else if (!_disposed) callback();
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
    _cancelTimers();
    final ready = _layoutReady;
    _layoutReady = null;
    if (ready != null && !ready.isCompleted) ready.complete();
    _offset?.removeListener(_scrolled);
    controller.removeListener(_playbackChanged);
    connection.dispose();
    _enter.dispose();
    _exit.dispose();
    scrollController.dispose();
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
