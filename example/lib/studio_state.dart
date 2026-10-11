import 'package:flutter/foundation.dart';
import 'package:flutter_lyric/flutter_lyric.dart';
import 'demo_presets.dart';

/// Each gallery entry owns its draft and history for this studio session.
class StudioState extends ChangeNotifier {
  StudioState({List<DemoPreset>? catalog}) : catalog = catalog ?? demoPresets;
  final List<DemoPreset> catalog;
  final Map<String, LyricPreset> _drafts = {};
  final Map<String, List<LyricPreset>> _undo = {};
  final Map<String, List<LyricPreset>> _redo = {};
  int _index = 0;
  LyricPreset? _gestureStart;
  String? _gestureId;
  DemoPreset get selected => catalog[_index];
  LyricPreset get preset => _drafts[selected.id] ?? selected.preset;
  bool isModified(DemoPreset item) =>
      (_drafts[item.id] ?? item.preset) != item.preset;
  bool get canUndo => _undo[selected.id]?.isNotEmpty ?? false;
  bool get canRedo => _redo[selected.id]?.isNotEmpty ?? false;

  void select(DemoPreset item) {
    endGesture();
    _index = catalog.indexOf(item);
    notifyListeners();
  }

  void beginGesture() {
    _gestureStart = preset;
    _gestureId = selected.id;
  }

  void endGesture() {
    if (_gestureStart != null &&
        _gestureId == selected.id &&
        _gestureStart != preset) {
      _remember(_gestureStart!);
      notifyListeners();
    }
    _gestureStart = null;
    _gestureId = null;
  }

  void _remember(LyricPreset value) {
    final history = _undo.putIfAbsent(selected.id, () => []);
    history.add(value);
    if (history.length > 60) history.removeAt(0);
    _redo[selected.id]?.clear();
  }

  void update(LyricPreset value) {
    if (value == preset) return;
    if (_gestureStart == null) _remember(preset);
    _drafts[selected.id] = value;
    notifyListeners();
  }

  void reset() => update(selected.preset);
  void undo() {
    endGesture();
    if (!canUndo) return;
    _redo.putIfAbsent(selected.id, () => []).add(preset);
    _drafts[selected.id] = _undo[selected.id]!.removeLast();
    notifyListeners();
  }

  void redo() {
    endGesture();
    if (!canRedo) return;
    _undo.putIfAbsent(selected.id, () => []).add(preset);
    _drafts[selected.id] = _redo[selected.id]!.removeLast();
    notifyListeners();
  }
}
