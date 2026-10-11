/// Supplies player-owned positions without introducing another playback clock.
///
/// [position] must return the current position whenever it is read. While
/// [isAdvancing] is true, the controller samples it while any attached view is enabled on every display frame.
/// [changes] must emit when playback starts, pauses, buffers, completes, changes
/// speed or seeks (including seeks while paused).
///
/// Controllers own their subscriptions to [changes], not the source or player.
/// The stream must support multiple listeners when sharing a source between
/// controllers. Prefer adapting an existing player stream instead of creating
/// a separate subscription that would need to be disposed by the caller.
abstract class LyricProgressSource {
  Duration get position;

  /// Whether the position is currently advancing, excluding buffering and end.
  bool get isAdvancing;

  Stream<void> get changes;
}
