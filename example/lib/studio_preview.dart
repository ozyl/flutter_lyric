// @dart=3.8

import 'dart:async';
import 'package:flutter_lyric/flutter_lyric.dart';

/// A line-timed preview that shares the host clock without editing its lyrics.
class StudioPreview implements LyricProgressSource {
  StudioPreview(this.parent) {
    controller = LyricController(progressSource: this);
    parent.addListener(_sync);
    _sync();
  }

  final LyricController parent;
  late final LyricController controller;
  final StreamController<void> _changes = StreamController<void>.broadcast(
    sync: true,
  );
  LyricDocument? _original;

  @override
  Duration get position => parent.progressSource?.position ?? parent.position;
  @override
  bool get isAdvancing =>
      parent.progressSource?.isAdvancing ?? parent.isAdvancing;
  @override
  Stream<void> get changes => _changes.stream;

  void _sync() {
    controller.timeOffset = parent.timeOffset;
    final document = parent.document;
    if (!identical(document, _original)) {
      _original = document;
      if (document == null) {
        controller.clear();
      } else {
        controller.loadDocument(
          document.copyWith(
            lines: document.lines
                .map(
                  (line) => LyricLine(
                    start: line.start,
                    text: line.text,
                    translation: line.translation,
                  ),
                )
                .toList(),
          ),
        );
      }
    }
    _changes.add(null);
  }

  void dispose() {
    parent.removeListener(_sync);
    controller.dispose();
    unawaited(_changes.close());
  }
}
