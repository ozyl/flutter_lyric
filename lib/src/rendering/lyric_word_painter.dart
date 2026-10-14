import 'dart:ui' as ui;
import 'package:flutter/painting.dart';
import 'package:flutter/rendering.dart' show Matrix4;
import '../compat/painting.dart';
import '../view/lyric_view_session.dart';
import 'lyric_word_layout.dart';
import 'lyric_word_raster.dart';

class LyricWordPainter {
  final LyricViewSession session;
  final Color? baseColor;
  final LyricWordRasterCache? rasterCache;
  final double pixelRatio;
  LyricWordPainter(this.session,
      {this.baseColor, this.rasterCache, this.pixelRatio = 1});
  void paint(Canvas canvas, LyricWordLine line, int index, double activity) {
    if (session.characterFloatEnabled) {
      _floatingMain(canvas, line, index, activity);
      return;
    }
    final segments = line.segments;
    if (segments.isEmpty) {
      if (!session.preset.highlight.enabled) {
        line.text.paint(canvas, Offset.zero);
        return;
      }
      _coloredMask(canvas, line, null, 1, activity);
      return;
    }
    // Unmatched text, spaces and glyph overhang remain at their original
    // position. Timed spans are removed before painting their lifted copies.
    canvas.save();
    canvas.clipPath(line.wordCutouts, doAntiAlias: false);
    line.text.paint(canvas, Offset.zero);
    canvas.restore();
    for (final segment in segments) {
      final progress = segment.progress(session.positionFor(index));
      final lift = session.wordPopLift(index, segment);
      canvas.save();
      canvas.translate(0, -lift);
      canvas.clipPath(segment.clipPath, doAntiAlias: false);
      _coloredMask(canvas, line, segment, progress, activity);
      canvas.restore();
    }
  }

  void _floatingMain(
      Canvas canvas, LyricWordLine line, int index, double activity) {
    final characters = line.characters;
    canvas.save();
    canvas.clipPath(line.characterCutouts, doAntiAlias: false);
    line.text.paint(canvas, Offset.zero);
    canvas.restore();
    final untimedLine = line.segments.isEmpty;
    final position = session.positionFor(index);
    final highlight = session.preset.highlight;
    final base = baseColor ??
        line.style.text.foreground?.color ??
        line.style.text.color ??
        const Color(0xFF000000);
    final active = highlight.color == null
        ? base
        : Color.alphaBlend(
            colorWithOpacity(
                highlight.color!, colorOpacity(highlight.color!) * activity),
            base);
    var raster = highlight.enabled && highlight.gradient == null
        ? rasterCache?.get(line, pixelRatio)
        : null;
    final basePaint = Paint()
      ..isAntiAlias = false
      ..filterQuality = FilterQuality.low
      ..colorFilter = ColorFilter.mode(base, BlendMode.srcIn);
    final activePaint = Paint()
      ..isAntiAlias = false
      ..filterQuality = FilterQuality.low
      ..colorFilter = ColorFilter.mode(active, BlendMode.srcIn);
    for (final character in characters) {
      if (character.clips.isEmpty) continue;
      final segment = character.segment;
      final pop = segment == null ? 0.0 : session.wordPopLift(index, segment);
      final lift = pop +
          session.characterFloatLift(index, character.ordinal, wordLine: line);
      if (raster != null && (untimedLine || segment != null)) {
        final uniform = _uniformHighlight(character,
            segment?.progress(position) ?? 1, highlight.tailFadeWidth);
        if (uniform != null) {
          try {
            raster.paintCharacter(canvas, character.ordinal, lift,
                uniform ? activePaint : basePaint);
            continue;
          } on Exception {
            // Deferred image rasterization can fail when first drawn. Keep the
            // existing renderer available, without retrying this atlas each frame.
            rasterCache!.reject(line);
            raster = null;
          }
        }
      }
      final bounds = character.bounds;
      // Translating drawParagraph itself snaps vertical glyph positions on
      // some engines. Move the rendered slice with bilinear sampling instead,
      // so even a subpixel breath stays continuous rather than stepping by 1px.
      canvas.saveLayer(
          bounds.expandToInclude(bounds.translate(0, -lift)).inflate(1),
          Paint()
            ..imageFilter = ui.ImageFilter.matrix(
                Matrix4.translationValues(0, -lift, 0).storage,
                filterQuality: FilterQuality.low));
      canvas.save();
      canvas.clipPath(character.clipPath, doAntiAlias: false);
      if (!session.preset.highlight.enabled ||
          (!untimedLine && segment == null)) {
        line.text.paint(canvas, Offset.zero);
      } else {
        // Highlight retains the timed word's geometry/progress, even when that
        // word contains several independently floating characters.
        // The translation layer already isolates coverage; reuse it for the
        // color mask instead of allocating another surface for every glyph.
        _coloredMask(
            canvas, line, segment, segment?.progress(position) ?? 1, activity,
            isolated: true);
      }
      canvas.restore();
      canvas.restore();
    }
  }

  // null means a highlight boundary crosses this slice. Such glyphs keep the
  // original composition, including the exact soft tail and bidi box order.
  bool? _uniformHighlight(
      LyricWordCharacter character, double progress, double tail) {
    if (progress <= 0) return false;
    final segment = character.segment;
    if (segment == null || progress >= 1) return true;
    var remaining = progress * (segment.highlightWidth + tail);
    bool? result;
    var matched = 0;
    for (var i = 0; i < segment.boxes.length; i++) {
      final box = segment.boxes[i];
      final wordClip = segment.clips[i];
      final width = box.right - box.left;
      for (final clip in character.clips) {
        if (!wordClip.overlaps(clip)) continue;
        // Include overhang in the test. The color field extends to a word's
        // outside edge only once its corresponding box is fully highlighted.
        final rtl = box.direction == TextDirection.rtl;
        final first = rtl ? box.right - clip.right : clip.left - box.left;
        final last = rtl ? box.right - clip.left : clip.right - box.left;
        final bool value;
        if (remaining <= 0 || first >= remaining) {
          value = false;
        } else if (remaining - tail >= width || last <= remaining - tail) {
          value = true;
        } else {
          return null;
        }
        if (result != null && result != value) return null;
        result = value;
        matched++;
      }
      remaining -= width;
    }
    return matched == character.clips.length ? result : null;
  }

  void _coloredMask(Canvas canvas, LyricWordLine line,
      LyricWordSegment? segment, double progress, double activity,
      {bool isolated = false}) {
    final highlight = session.preset.highlight;
    final base = baseColor ??
        line.style.text.foreground?.color ??
        line.style.text.color ??
        const Color(0xFF000000);
    final bounds = segment == null || segment.boxes.isEmpty
        ? line.paintBounds
        : segment.bounds;
    if (!isolated) canvas.saveLayer(bounds, Paint());
    line.mask.paint(canvas, Offset.zero);
    if (highlight.gradient == null) {
      _solidColors(canvas, segment, bounds, base, progress, activity);
      if (!isolated) canvas.restore();
      return;
    }
    // Compose base and highlight BEFORE applying glyph coverage. This avoids
    // double-antialiased edges and keeps highlight alpha independent of base.
    canvas.saveLayer(bounds, Paint()..blendMode = BlendMode.srcIn);
    canvas.drawRect(
        bounds,
        Paint()
          ..isAntiAlias = false
          ..color = base);
    if (highlight.enabled && progress > 0) {
      final gradient = highlight.gradient ??
          LinearGradient(colors: [highlight.color!, highlight.color!]);
      final paint = Paint()
        ..isAntiAlias = false
        ..shader = LinearGradient(
          colors: gradient.colors
              .map((c) => colorWithOpacity(c, colorOpacity(c) * activity))
              .toList(),
          stops: gradient.stops,
          begin: gradient.begin,
          end: gradient.end,
          tileMode: gradient.tileMode,
          transform: gradient.transform,
        ).createShader(bounds);
      if (segment == null || progress >= 1) {
        canvas.drawRect(bounds, paint);
      } else {
        final total = segment.boxes
            .fold<double>(0, (sum, box) => sum + box.right - box.left);
        final tail = highlight.tailFadeWidth;
        var remaining = progress * (total + tail);
        for (var i = 0; i < segment.boxes.length; i++) {
          final box = segment.boxes[i];
          final rect = box.toRect();
          final clip = segment.clips[i];
          final width = rect.width;
          final solid = (remaining - tail).clamp(0.0, width);
          final extent = remaining.clamp(0.0, width);
          final rtl = box.direction == TextDirection.rtl;
          if (solid > 0) {
            canvas.drawRect(
                Rect.fromLTRB(
                    rtl
                        ? (solid >= width ? clip.left : rect.right - solid)
                        : clip.left,
                    clip.top,
                    rtl
                        ? clip.right
                        : (solid >= width ? clip.right : rect.left + solid),
                    clip.bottom),
                paint);
          }
          if (tail > 0 && extent > solid) {
            final start = remaining - tail;
            final end = remaining;
            final fadeRect = Rect.fromLTRB(
                rtl ? rect.right - end : rect.left + start,
                clip.top,
                rtl ? rect.right - start : rect.left + end,
                clip.bottom);
            canvas.saveLayer(clip, Paint());
            canvas.drawRect(
                Rect.fromLTRB(
                    rtl
                        ? (extent >= width ? clip.left : rect.right - extent)
                        : (solid <= 0 ? clip.left : rect.left + solid),
                    clip.top,
                    rtl
                        ? (solid <= 0 ? clip.right : rect.right - solid)
                        : (extent >= width ? clip.right : rect.left + extent),
                    clip.bottom),
                paint);
            canvas.drawRect(
                clip,
                Paint()
                  ..isAntiAlias = false
                  ..blendMode = BlendMode.dstIn
                  ..shader = LinearGradient(
                    begin: rtl ? Alignment.centerRight : Alignment.centerLeft,
                    end: rtl ? Alignment.centerLeft : Alignment.centerRight,
                    colors: const [Color(0xFFFFFFFF), Color(0x00FFFFFF)],
                  ).createShader(fadeRect));
            canvas.restore();
          }
          remaining -= width;
        }
      }
    }
    canvas.restore();
    if (!isolated) canvas.restore();
  }

  // Each pixel replaces neutral coverage exactly once. Composing the base
  // behind the fade shader before srcIn preserves translucent colors without
  // a second color group or a third layer for the trailing fade.
  void _solidColors(Canvas canvas, LyricWordSegment? segment, Rect bounds,
      Color base, double progress, double activity) {
    final highlight = session.preset.highlight;
    final color = highlight.color;
    final basePaint = Paint()
      ..isAntiAlias = false
      ..blendMode = BlendMode.srcIn
      ..color = base;
    if (color == null || progress <= 0 || activity <= 0) {
      canvas.drawRect(bounds, basePaint);
      return;
    }
    final active = colorWithOpacity(color, colorOpacity(color) * activity);
    final solidPaint = Paint()
      ..isAntiAlias = false
      ..blendMode = BlendMode.srcIn
      ..color = Color.alphaBlend(active, base);
    if (segment == null || progress >= 1) {
      canvas.drawRect(bounds, solidPaint);
      return;
    }
    final tail = highlight.tailFadeWidth;
    var remaining = progress * (segment.highlightWidth + tail);
    for (var i = 0; i < segment.boxes.length; i++) {
      final box = segment.boxes[i];
      final clip = segment.clips[i];
      final rtl = box.direction == TextDirection.rtl;
      final width = box.right - box.left;
      // Coordinates increase in reading order; extend the outer edges so
      // glyph overhang is colored as well as the typographic bounds.
      final start = rtl ? box.right - clip.right : clip.left - box.left;
      final end = rtl ? box.right - clip.left : clip.right - box.left;
      Rect rect(double a, double b) => Rect.fromLTRB(
          rtl ? box.right - b : box.left + a,
          clip.top,
          rtl ? box.right - a : box.left + b,
          clip.bottom);
      final solid = (remaining - tail).clamp(0.0, width);
      final extent = remaining.clamp(0.0, width);
      final solidEnd = solid <= 0 ? start : (solid >= width ? end : solid);
      final fadeEnd = extent <= 0 ? start : (extent >= width ? end : extent);
      if (solidEnd > start) {
        canvas.drawRect(rect(start, solidEnd), solidPaint);
      }
      if (tail > 0 && fadeEnd > solidEnd) {
        canvas.drawRect(
            rect(solidEnd, fadeEnd),
            Paint()
              ..isAntiAlias = false
              ..blendMode = BlendMode.srcIn
              ..colorFilter = ColorFilter.mode(base, BlendMode.dstOver)
              ..shader = LinearGradient(
                begin: rtl ? Alignment.centerRight : Alignment.centerLeft,
                end: rtl ? Alignment.centerLeft : Alignment.centerRight,
                colors: [active, colorWithOpacity(active, 0)],
              ).createShader(rect(remaining - tail, remaining)));
      }
      if (fadeEnd < end) canvas.drawRect(rect(fadeEnd, end), basePaint);
      remaining -= width;
    }
  }
}
