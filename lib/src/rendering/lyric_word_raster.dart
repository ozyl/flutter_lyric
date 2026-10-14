import 'dart:collection';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/painting.dart';
import 'lyric_word_layout.dart';

/// A bounded per-view atlas cache. Every glyph has a transparent gutter so
/// bilinear sampling cannot pull coverage from a differently moving neighbor.
class LyricWordRasterCache {
  static const maxEntries = 4;
  static const maxBytes = 32 * 1024 * 1024;
  static const maxDimension = 4096;
  final _entries = LinkedHashMap<LyricWordLine, LyricWordRaster>();
  final _rejected = LinkedHashSet<LyricWordLine>();
  double? _pixelRatio;
  int _bytes = 0;
  bool _supported = true;

  int get debugEntryCount => _entries.length;
  int get debugBytes => _bytes;

  LyricWordRaster? get(LyricWordLine line, double pixelRatio) {
    if (!_supported || !pixelRatio.isFinite || pixelRatio <= 0) return null;
    if (_pixelRatio != pixelRatio) {
      clear();
      _pixelRatio = pixelRatio;
    }
    if (_rejected.contains(line)) return null;
    final previous = _entries.remove(line);
    if (previous != null) {
      _entries[line] = previous;
      return previous;
    }
    final slices = <_Slice>[];
    var area = 0;
    var widest = 0;
    for (final character in line.characters) {
      final bounds = character.bounds;
      // Integer pixel cells include transparent gutters on all four edges.
      final left = (bounds.left * pixelRatio).floor() - 1;
      final top = (bounds.top * pixelRatio).floor() - 1;
      final right = (bounds.right * pixelRatio).ceil() + 1;
      final bottom = (bounds.bottom * pixelRatio).ceil() + 1;
      final clipPath = Path();
      for (final clip in character.clips) {
        clipPath.addRect(Rect.fromLTRB(clip.left, clip.top - 1 / pixelRatio,
            clip.right, clip.bottom + 1 / pixelRatio));
      }
      final slice = _Slice(
          Rect.fromLTRB(left / pixelRatio, top / pixelRatio, right / pixelRatio,
              bottom / pixelRatio),
          right - left,
          bottom - top,
          clipPath);
      slices.add(slice);
      area += slice.width * slice.height;
      widest = math.max(widest, slice.width);
    }
    // Per-entry budget guarantees that old/new lines cannot evict each other
    // every frame. Unusually large lines retain the paragraph fallback.
    const entryBytes = maxBytes ~/ maxEntries;
    if (area == 0 || area * 4 > entryBytes || widest > maxDimension) {
      reject(line);
      return null;
    }
    final rowWidth = math.max(widest, math.sqrt(area).ceil());
    var x = 0;
    var y = 0;
    var rowHeight = 0;
    var width = 0;
    // Tall first/last-row clips include overhang. Packing them together avoids
    // reserving their extra height for many short middle-row cells.
    final packed = slices.toList()
      ..sort((a, b) => b.height.compareTo(a.height));
    for (final slice in packed) {
      if (x + slice.width > rowWidth) {
        y += rowHeight;
        x = 0;
        rowHeight = 0;
      }
      slice.source = Rect.fromLTWH(x.toDouble(), y.toDouble(),
          slice.width.toDouble(), slice.height.toDouble());
      x += slice.width;
      width = math.max(width, x);
      rowHeight = math.max(rowHeight, slice.height);
    }
    final height = y + rowHeight;
    final bytes = width * height * 4;
    if (width > maxDimension || height > maxDimension || bytes > entryBytes) {
      reject(line);
      return null;
    }
    while (_entries.length >= maxEntries) {
      final oldest = _entries.remove(_entries.keys.first)!;
      _bytes -= oldest.bytes;
      oldest.dispose();
    }
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    for (var i = 0; i < slices.length; i++) {
      final character = line.characters[i];
      if (character.clips.isEmpty) continue;
      final slice = slices[i];
      canvas.save();
      canvas.clipRect(slice.source, doAntiAlias: false);
      canvas.translate(slice.source.left, slice.source.top);
      canvas.scale(pixelRatio);
      canvas.translate(-slice.destination.left, -slice.destination.top);
      canvas.clipPath(character.clipPath, doAntiAlias: false);
      line.mask.paint(canvas, Offset.zero);
      canvas.restore();
    }
    final picture = recorder.endRecording();
    try {
      // Flutter 2 uses the existing paragraph path. Modern engines return a
      // handle immediately and rasterize on the raster thread, without readback.
      final image = (picture as dynamic).toImageSync(width, height) as ui.Image;
      final raster = LyricWordRaster(image, slices, bytes);
      _entries[line] = raster;
      _bytes += bytes;
      return raster;
    } on NoSuchMethodError {
      _supported = false;
      return null;
    } on UnsupportedError {
      _supported = false;
      return null;
    } on Exception {
      reject(line);
      return null;
    } finally {
      _disposeNative(picture);
    }
  }

  void reject(LyricWordLine line) {
    final previous = _entries.remove(line);
    if (previous != null) {
      _bytes -= previous.bytes;
      previous.dispose();
    }
    _rejected.remove(line);
    _rejected.add(line);
    if (_rejected.length > maxEntries) _rejected.remove(_rejected.first);
  }

  void clear() {
    for (final entry in _entries.values) {
      entry.dispose();
    }
    _entries.clear();
    _rejected.clear();
    _bytes = 0;
  }
}

class LyricWordRaster {
  final ui.Image image;
  final List<_Slice> _slices;
  final int bytes;
  LyricWordRaster(this.image, this._slices, this.bytes);

  void paintCharacter(Canvas canvas, int ordinal, double lift, Paint paint) {
    final slice = _slices[ordinal];
    canvas.save();
    try {
      canvas.translate(0, -lift);
      // Match horizontal clipping with adjacent paragraph slices at the final
      // pixel phase, preventing double coverage at mixed highlight boundaries.
      // Keep one physical pixel vertically for the bilinear motion footprint.
      canvas.clipPath(slice.clipPath, doAntiAlias: false);
      canvas.drawImageRect(image, slice.source, slice.destination, paint);
    } finally {
      canvas.restore();
    }
  }

  void dispose() => _disposeNative(image);
}

class _Slice {
  final Rect destination;
  final int width, height;
  final Path clipPath;
  late Rect source;
  _Slice(this.destination, this.width, this.height, this.clipPath);
}

void _disposeNative(dynamic object) {
  try {
    object.dispose();
  } on NoSuchMethodError {
    // Older engines release native resources when Dart drops the reference.
  }
}
