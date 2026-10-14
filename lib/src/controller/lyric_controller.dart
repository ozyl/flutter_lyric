import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import '../model/lyric_document.dart';
import '../parser/lyric_parser.dart';
import 'lyric_progress_source.dart';

/// One atomic snapshot. [position] is player time; [effectivePosition] includes
/// the document offset and the user's [timeOffset].
@immutable
class LyricPlaybackState {
  final LyricDocument? document;
  final Duration position;
  final Duration timeOffset;
  final Duration effectivePosition;
  final int? activeLineIndex;
  final bool isAdvancing;

  const LyricPlaybackState(
      {required this.document,
      required this.position,
      required this.timeOffset,
      required this.effectivePosition,
      required this.activeLineIndex,
      required this.isAdvancing});
}

/// Shared lyrics and playback state. Selection and scrolling belong to each
/// attached view. This controller owns subscriptions, never the player/source.
class LyricController implements ValueListenable<LyricPlaybackState> {
  LyricController({
    LyricDocument? document,
    LyricProgressSource? progressSource,
    Duration initialPosition = Duration.zero,
    Duration timeOffset = Duration.zero,
  }) {
    _activeIndex = _ActiveIndexListenable(this);
    _state = _snapshot(document, initialPosition, timeOffset, false);
    this.progressSource = progressSource;
  }

  late LyricPlaybackState _state;
  late final _ActiveIndexListenable _activeIndex;
  final _ControllerChanges _changes = _ControllerChanges();
  final Map<Object, LyricViewConnection> _views = {};
  LyricProgressSource? _source;
  StreamSubscription<void>? _subscription;
  _ProgressSampler? _sampler;
  bool _disposed = false;
  int _documentRevision = 0;

  @override
  LyricPlaybackState get value => _state;
  LyricDocument? get document => value.document;
  Duration get position => value.position;
  Duration get effectivePosition => value.effectivePosition;
  int? get activeLineIndex => value.activeLineIndex;
  LyricLine? get activeLine =>
      activeLineIndex == null ? null : document!.lines[activeLineIndex!];
  bool get isAdvancing => value.isAdvancing;
  Duration get timeOffset => value.timeOffset;
  ValueListenable<int?> get activeLineIndexListenable => _activeIndex;
  bool get hasClients => _views.isNotEmpty;
  List<Object> get attachedViewIds => List.unmodifiable(_views.keys);

  set timeOffset(Duration value) {
    _checkAlive();
    _publish(_snapshot(document, position, value, isAdvancing));
  }

  void load(String lyric,
      {String? translation, LyricParser? parser, Duration? vocalStart}) {
    _checkAlive();
    loadDocument(LyricDocument.parse(lyric,
        translation: translation, parser: parser, vocalStart: vocalStart));
  }

  void loadDocument(LyricDocument document) {
    _checkAlive();
    _documentRevision++;
    _publish(_snapshot(document, position, timeOffset, isAdvancing),
        force: true);
  }

  /// Clears lyrics while keeping player position and user calibration.
  void clear() {
    _checkAlive();
    _documentRevision++;
    _publish(_snapshot(null, position, timeOffset, isAdvancing), force: true);
  }

  void setPosition(Duration position) {
    _checkAlive();
    if (_source != null) {
      throw StateError(
          'Clear progressSource before setting a manual position.');
    }
    _publish(_snapshot(document, position, timeOffset, false));
  }

  LyricProgressSource? get progressSource => _source;
  set progressSource(LyricProgressSource? source) {
    _checkAlive();
    if (identical(source, _source)) return;
    _subscription?.cancel();
    _subscription = null;
    _source = source;
    if (source != null) {
      _subscription = source.changes.listen((_) {
        if (!_disposed && identical(_source, source)) _sample();
      });
    }
    _sample();
  }

  void _sample() {
    if (_disposed) return;
    final source = _source;
    _publish(_snapshot(document, source?.position ?? position, timeOffset,
        source?.isAdvancing ?? false));
    _sampler?.update();
  }

  LyricPlaybackState _snapshot(LyricDocument? document, Duration position,
      Duration timeOffset, bool advancing) {
    final effective =
        position + (document?.offset ?? Duration.zero) + timeOffset;
    final lines = document?.lines ?? const <LyricLine>[];
    var low = 0;
    var high = lines.length;
    // Upper bound gives a deterministic last entry for duplicate timestamps.
    while (low < high) {
      final mid = low + ((high - low) >> 1);
      if (lines[mid].start <= effective) {
        low = mid + 1;
      } else {
        high = mid;
      }
    }
    return LyricPlaybackState(
        document: document,
        position: position,
        timeOffset: timeOffset,
        effectivePosition: effective,
        activeLineIndex: low == 0 ? null : low - 1,
        isAdvancing: advancing);
  }

  void _publish(LyricPlaybackState next, {bool force = false}) {
    final old = _state;
    if (!force &&
        identical(old.document, next.document) &&
        old.position == next.position &&
        old.timeOffset == next.timeOffset &&
        old.isAdvancing == next.isAdvancing) {
      return;
    }
    _state = next;
    if (old.activeLineIndex != next.activeLineIndex) _activeIndex.changed();
    if (!_disposed) _changes.changed();
  }

  Future<void> resumeFollow({Object? viewId, bool animate = true}) {
    _checkAlive();
    return Future.wait(_targets(viewId).map((view) => view.resume(animate)))
        .then((_) {});
  }

  Future<void> scrollToLine(int index, {Object? viewId, bool animate = true}) {
    _checkAlive();
    final targets = _targets(viewId);
    if (targets.isEmpty) return Future<void>.value();
    if (index < 0 || index >= (document?.lines.length ?? 0)) {
      throw RangeError.index(index, document?.lines ?? const <LyricLine>[]);
    }
    return Future.wait(targets.map((view) => view.scroll(index, animate)))
        .then((_) {});
  }

  List<LyricViewConnection> _targets(Object? id) {
    if (id == null) return _views.values.toList();
    final target = _views[id];
    if (target == null) throw StateError('No attached LyricView with id $id.');
    return [target];
  }

  void _checkAlive() {
    if (_disposed) throw StateError('LyricController has been disposed.');
  }

  @override
  void addListener(VoidCallback listener) {
    _checkAlive();
    _changes.addListener(listener);
  }

  @override
  void removeListener(VoidCallback listener) {
    if (!_disposed) _changes.removeListener(listener);
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _subscription?.cancel();
    _subscription = null;
    _source = null;
    _sampler?.dispose();
    _sampler = null;
    for (final view in _views.values) {
      view._attached = false;
    }
    _views.clear();
    _activeIndex.dispose();
    _changes.dispose();
  }
}

class _ActiveIndexListenable extends ChangeNotifier
    implements ValueListenable<int?> {
  final LyricController controller;
  _ActiveIndexListenable(this.controller);
  @override
  int? get value => controller.activeLineIndex;
  void changed() => notifyListeners();
}

/// Internal view registration. Not exported by the package's public library.
class LyricViewConnection {
  final LyricController controller;
  final Object id;
  final Future<void> Function(bool animate) resume;
  final Future<void> Function(int index, bool animate) scroll;
  bool _enabled = false;
  bool _attached = true;
  int get documentRevision => controller._documentRevision;

  LyricViewConnection(
      {required this.controller,
      required this.id,
      required this.resume,
      required this.scroll}) {
    controller._checkAlive();
    if (controller._views.containsKey(id)) {
      throw StateError('LyricView ids must be unique per controller: $id.');
    }
    controller._views[id] = this;
    controller._sampler ??= _ProgressSampler(controller);
  }

  set enabled(bool value) {
    if (!_attached || value == _enabled) return;
    _enabled = value;
    controller._sampler?.update();
  }

  void dispose() {
    if (!_attached) return;
    _attached = false;
    controller._views.remove(id);
    if (controller._views.isEmpty) {
      controller._sampler?.dispose();
      controller._sampler = null;
    } else {
      controller._sampler?.update();
    }
  }
}

class _ProgressSampler with WidgetsBindingObserver {
  final LyricController controller;
  late final Ticker _ticker;
  late final WidgetsBinding _binding;
  bool _foreground = true;

  _ProgressSampler(this.controller) {
    // Explicit nullable type supports Flutter 2's nullable binding singleton.
    final WidgetsBinding? binding = WidgetsBinding.instance;
    _binding = binding!;
    _foreground = _binding.lifecycleState == null ||
        _binding.lifecycleState == AppLifecycleState.resumed;
    _ticker = Ticker((_) => controller._sample());
    _binding.addObserver(this);
  }

  void update() {
    final enabled = _foreground &&
        controller.isAdvancing &&
        controller._views.values.any((view) => view._enabled);
    if (enabled && !_ticker.isActive) _ticker.start();
    if (!enabled && _ticker.isActive) _ticker.stop();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    if (_foreground) controller._sample();
    update();
  }

  void dispose() {
    _binding.removeObserver(this);
    _ticker.dispose();
  }
}

class _ControllerChanges extends ChangeNotifier {
  void changed() => notifyListeners();
}
