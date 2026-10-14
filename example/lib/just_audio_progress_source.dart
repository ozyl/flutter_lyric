// @dart=3.8

import 'dart:async';

import 'package:flutter_lyric/flutter_lyric.dart';
import 'package:just_audio/just_audio.dart';

/// Keeps native clock corrections from rewinding lyrics between real seeks.
/// Subscriptions live only as long as a controller listens to [changes].
class JustAudioProgressSource implements LyricProgressSource {
  JustAudioProgressSource(this.player);

  final AudioPlayer player;
  Duration? _lastPosition;
  AudioSource? _audioSource;
  int? _index;
  ProcessingState? _processingState;
  int _listeners = 0;

  void _checkTimeline() {
    final state = player.processingState;
    // Loading events may still carry the previous track's position. Reset
    // again on leaving loading so that value cannot become the new floor.
    if (!identical(_audioSource, player.audioSource) ||
        _index != player.currentIndex ||
        state == ProcessingState.idle ||
        state == ProcessingState.loading ||
        _processingState == ProcessingState.idle ||
        _processingState == ProcessingState.loading) {
      _lastPosition = null;
    }
    _audioSource = player.audioSource;
    _index = player.currentIndex;
    _processingState = state;
  }

  @override
  Duration get position {
    _checkTimeline();
    final current = player.position;
    // just_audio extrapolates immediately on play. libmpv can then report an
    // older position (including zero) before its output clock catches up.
    // Hold the last displayed position until it catches up; add no new clock.
    if (_lastPosition == null || current > _lastPosition!) {
      _lastPosition = current;
    }
    return _lastPosition!;
  }

  @override
  bool get isAdvancing =>
      player.playing && player.processingState == ProcessingState.ready;

  @override
  Stream<void> get changes => _changes;

  late final Stream<void> _changes = Stream<void>.multi((events) {
    // A seek may have happened while this source had no listeners.
    if (_listeners++ == 0) _lastPosition = null;
    final updates = player.playerEventStream.listen(
      (_) {
        _checkTimeline();
        events.add(null);
      },
      onError: events.addError,
      onDone: events.close,
    );
    final jumps = player.positionDiscontinuityStream.listen((_) {
      _lastPosition = null;
      events.add(null);
    }, onError: events.addError);
    events.onCancel = () async {
      _listeners--;
      await Future.wait([updates.cancel(), jumps.cancel()]);
    };
  }, isBroadcast: true);
}
