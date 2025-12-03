import 'dart:ui' show VoidCallback;

import 'package:flutter/widgets.dart' show ValueNotifier;
import 'package:flutter_lyric/core/lyric_parse.dart';

import 'lyric_model.dart';

enum LyricEvent {
  stopSelection,
  resumeActiveLine,
  resumeSelectedLine,
  playSwitchAnimation,
  tapLine,
  reset,
}

class LyricController {
  // 歌词
  final ValueNotifier<LyricModel?> lyricNotifier = ValueNotifier(null);
  // 当前播放行
  final ValueNotifier<int> activeIndexNotifiter = ValueNotifier(0);
  // 锚点位置
  final ValueNotifier<double> anchorPositionNotifier = ValueNotifier(0);
  // 高亮索引
  late ValueNotifier<int> selectedIndexNotifier = ValueNotifier(0);

  var anchorAlignOffsetY = 0.0;
  var selectedMaxWidth = 0.0;
  var _lyricOffset = 0;

  set lyricOffset(int value) {
    _lyricOffset = value;
    activeIndexNotifiter.value = getIndexByProgress(progressNotifier.value);
  }

  int get lyricOffset => _lyricOffset;

  final ValueNotifier<double> selectedLineHeightNotifier = ValueNotifier(0);

  final ValueNotifier<bool> isSelectingNotifier = ValueNotifier(false);
  late final ValueNotifier<Duration> progressNotifier =
      ValueNotifier(Duration.zero);

  void stopSelection() {
    notifyEvent(LyricEvent.stopSelection);
  }

  void notifyEvent(LyricEvent event, [dynamic data]) {
    _eventCallbacks[event]?.forEach((callback) {
      callback(data);
    });
  }

  Function(dynamic)? _onTapLineCallback;

  void cancelOnTapLineCallback() {
    if (_onTapLineCallback != null) {
      unregisterEvent(LyricEvent.tapLine, _onTapLineCallback!);
      _onTapLineCallback = null;
    }
  }

  void setOnTapLineCallback(Function(Duration) callback) {
    cancelOnTapLineCallback();
    registerEvent(
        LyricEvent.tapLine,
        _onTapLineCallback = (data) {
          final index = data as int;
          return callback(
              lyricNotifier.value?.lines[index].start ?? Duration.zero);
        });
  }

  final Map<LyricEvent, List<Function(dynamic)>> _eventCallbacks = {};

  VoidCallback registerEvent(LyricEvent event, Function(dynamic) callback) {
    _eventCallbacks[event] ??= [];
    _eventCallbacks[event]!.add(callback);
    return () {
      unregisterEvent(event, callback);
    };
  }

  void unregisterEvent(LyricEvent event, Function(dynamic) callback) {
    _eventCallbacks[event]?.remove(callback);
  }

  void loadLyric(String lyric, {String? translationLyric}) {
    final lyricModel = LyricParse.parse(
      lyric,
      translationLyric: translationLyric,
    );
    loadLyricModel(lyricModel);
  }

  void loadLyricModel(LyricModel lyricModel) {
    notifyEvent(LyricEvent.stopSelection);
    notifyEvent(LyricEvent.reset);
    lyricNotifier.value = lyricModel;
    activeIndexNotifiter.value = getIndexByProgress(progressNotifier.value);
    lyricOffset = lyricModel.offset;
  }

  setProgress(Duration progress) {
    progressNotifier.value = progress;
    final playIndex = getIndexByProgress(
      progress,
    );
    activeIndexNotifiter.value = playIndex;
  }

  int getIndexByProgress(Duration progress) {
    final model = lyricNotifier.value;
    if (model == null) {
      return 0;
    }
    progress += Duration(milliseconds: _lyricOffset);
    int left = 0;
    final lines = model.lines;
    int right = lines.length - 1;
    int result = -1;

    while (left <= right) {
      int mid = left + ((right - left) >> 1);
      if (progress == lines[mid].start) {
        return mid;
      } else if (progress < lines[mid].start) {
        right = mid - 1;
      } else {
        result = mid;
        left = mid + 1;
      }
    }
    return result < 0 ? 0 : result;
  }

  void dispose() {
    _eventCallbacks.clear();
    lyricNotifier.dispose();
    progressNotifier.dispose();
    activeIndexNotifiter.dispose();
    anchorPositionNotifier.dispose();
    selectedIndexNotifier.dispose();
    selectedLineHeightNotifier.dispose();
    isSelectingNotifier.dispose();
  }
}
