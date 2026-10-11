// @dart=3.8

import 'package:flutter/animation.dart';
import 'package:flutter_lyric/flutter_lyric.dart';

// Keep the original resolver across repeated edits, including a zero duration.
// Weak keys let discarded history entries (and their resolvers) be collected.
final _origins = Expando<({LyricScrollAnimation base, Curve? curve})>();

LyricScrollAnimation tuneScroll(
  LyricScrollAnimation source, {
  int? milliseconds,
  Curve? curve,
}) {
  final origin = _origins[source];
  final base = origin?.base ?? source;
  final selectedCurve = curve ?? origin?.curve;
  final reference = base.resolve(100).duration.inMilliseconds;
  final desired = milliseconds ?? source.resolve(100).duration.inMilliseconds;
  final factor = reference == 0 ? 1.0 : desired / reference;
  Duration duration(Duration value) => reference == 0
      ? Duration(milliseconds: desired)
      : Duration(milliseconds: (value.inMilliseconds * factor).round());
  final LyricScrollAnimation result;
  if (base.resolver != null) {
    result = LyricScrollAnimation.custom((distance) {
      final animation = base.resolve(distance);
      return LyricAnimation(
        duration: duration(animation.duration),
        curve: selectedCurve ?? animation.curve,
      );
    });
  } else if (base.durations.isNotEmpty) {
    result = LyricScrollAnimation.byDistance(
      durations: base.durations.map(
        (distance, time) => MapEntry(distance, duration(time)),
      ),
      duration: duration(base.duration),
      curve: selectedCurve ?? base.curve,
    );
  } else {
    result = LyricScrollAnimation.fixed(
      duration: duration(base.duration),
      curve: selectedCurve ?? base.curve,
    );
  }
  _origins[result] = (base: base, curve: selectedCurve);
  return result;
}
