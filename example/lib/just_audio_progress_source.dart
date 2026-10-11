// @dart=3.8

import 'package:flutter_lyric/flutter_lyric.dart';
import 'package:just_audio/just_audio.dart';

/// Adapts just_audio without owning the player or a separate stream subscription.
class JustAudioProgressSource implements LyricProgressSource {
  JustAudioProgressSource(this.player);

  final AudioPlayer player;

  @override
  Duration get position => player.position;

  @override
  bool get isAdvancing =>
      player.playing && player.processingState == ProcessingState.ready;

  @override
  Stream<void> get changes => player.playerEventStream.map<void>((_) {});
}
