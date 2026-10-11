import 'package:flutter/widgets.dart';
import '../model/lyric_document.dart';

/// A line in a particular view, including its offset-corrected player time.
@immutable
class LyricLineDetails {
  final Object viewId;
  final int index;
  final LyricLine line;
  final Duration seekPosition;

  const LyricLineDetails(
      {required this.viewId,
      required this.index,
      required this.line,
      required this.seekPosition});

  @override
  bool operator ==(Object other) =>
      other is LyricLineDetails &&
      viewId == other.viewId &&
      index == other.index &&
      identical(line, other.line) &&
      seekPosition == other.seekPosition;
  @override
  int get hashCode =>
      viewId.hashCode ^ index.hashCode ^ line.hashCode ^ seekPosition.hashCode;
}

typedef LyricSelectionBuilder = Widget Function(
    BuildContext context, LyricSelectionDetails details);

/// Viewport-local selection geometry for presentation builders. [onTap]
/// dispatches the owning view's business callback; [resumeFollow] affects only
/// that view. The callbacks become no-ops if their view/document is replaced.
@immutable
class LyricSelectionDetails {
  final LyricLineDetails line;
  final Size viewportSize;
  final Rect lineRect;
  final Rect contentRect;
  final double anchorY;
  final bool isActive;
  final bool isDragging;
  final bool isSnapped;
  final VoidCallback? onTap;
  final VoidCallback resumeFollow;

  const LyricSelectionDetails(
      {required this.line,
      required this.viewportSize,
      required this.lineRect,
      required this.contentRect,
      required this.anchorY,
      required this.isActive,
      required this.isDragging,
      required this.isSnapped,
      required this.onTap,
      required this.resumeFollow});
}
