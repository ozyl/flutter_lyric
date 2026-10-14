/// Smooth endpoints (zero velocity and acceleration) avoid a bounce at either
/// end of a lift. These functions are deterministic and never advance playback.
double _smooth(double value) {
  final t = value.clamp(0.0, 1.0);
  return t * t * t * (t * (t * 6 - 15) + 10);
}

double _pulse(double phase, double crest) => phase < crest
    ? _smooth(phase / crest)
    : 1 - _smooth((phase - crest) / (1 - crest));

/// Rise at the word onset, then hold until the session releases line activity.
double lyricWordPop(Duration position, Duration start, Duration duration) {
  if (duration <= Duration.zero || position <= start) return 0;
  final phase = (position - start).inMicroseconds / duration.inMicroseconds;
  return _smooth(phase);
}

// Bounded, stable variation per cycle; no frame-by-frame random jitter.
double _variation(int cycle, int seed) {
  final value = ((cycle + seed * 101) * 1664525 + 1013904223) & 0x7fffffff;
  return ((value ^ (value >> 11)) & 1023) / 1023;
}

/// Signed drift around zero, independent of the height held by Word Pop.
/// Neighbors sample the same delayed wave, bounded by -1 and +1.
double lyricCharacterFloat(Duration elapsed, Duration period, Duration stagger,
    int character, int line) {
  if (period <= Duration.zero) return 0;
  final time = (elapsed.inMicroseconds - character * stagger.inMicroseconds) /
      period.inMicroseconds;
  final drift = time / 2.7;
  final step = drift.floor();
  final warp = _variation(step, line + 17) +
      (_variation(step + 1, line + 17) - _variation(step, line + 17)) *
          _smooth(drift - step);
  final phase = time + .16 * warp + line * .137;
  final cycle = phase.floor();
  final crest = .38 + .1 * _variation(cycle, line + 31);
  final amplitude = .78 + .22 * _variation(cycle, line + 53);
  final entrance = _smooth(elapsed.inMicroseconds / 1400000);
  final fraction = phase - cycle;
  // Both halves return to zero with smooth endpoints, so varying the amplitude
  // between cycles cannot introduce a jump or shift the suspended position.
  final wave = fraction < .5
      ? _pulse(fraction * 2, crest)
      : -_pulse((fraction - .5) * 2, crest);
  return entrance * amplitude * wave;
}
