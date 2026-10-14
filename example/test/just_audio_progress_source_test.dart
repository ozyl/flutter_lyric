// @dart=3.8

import 'dart:async';

import 'package:flutter_lyric/flutter_lyric.dart';
import 'package:flutter_lyric_example/just_audio_progress_source.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:just_audio/just_audio.dart';

class _Player implements AudioPlayer {
  final updates = StreamController<PlayerEvent>.broadcast(sync: true);
  final jumps = StreamController<PositionDiscontinuity>.broadcast(sync: true);
  @override
  Duration position = Duration.zero;
  @override
  bool playing = false;
  @override
  ProcessingState processingState = ProcessingState.ready;
  @override
  int? currentIndex = 0;
  @override
  AudioSource? audioSource = AudioSource.uri(Uri.parse('asset:///music.mp3'));
  @override
  Stream<PlayerEvent> get playerEventStream => updates.stream;
  @override
  Stream<PositionDiscontinuity> get positionDiscontinuityStream => jumps.stream;

  void update(int milliseconds) {
    position = Duration(milliseconds: milliseconds);
    updates.add(PlayerEvent());
  }

  void emitSeek(int milliseconds) {
    final previous = PlaybackEvent(updatePosition: position);
    update(milliseconds);
    jumps.add(
      PositionDiscontinuity(
        PositionDiscontinuityReason.seek,
        previous,
        PlaybackEvent(updatePosition: position),
      ),
    );
  }

  Future<void> close() async {
    await updates.close();
    await jumps.close();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late _Player player;
  late JustAudioProgressSource source;
  late LyricController controller;

  setUp(() {
    player = _Player();
    source = JustAudioProgressSource(player);
    controller = LyricController(progressSource: source)
      ..load('[00:00.00]Title\n[00:00.04]Credits\n[00:00.12]First line');
  });
  tearDown(() async {
    controller.dispose();
    await player.close();
  });

  Future<void> update(int milliseconds) async {
    player.update(milliseconds);
    await Future<void>.delayed(Duration.zero);
  }

  test('startup corrections hold word progress and the active line', () async {
    player.playing = true;
    await update(150);
    expect(controller.activeLineIndex, 2);
    for (final position in [0, 28, 41, 110]) {
      await update(position);
      expect(controller.position, const Duration(milliseconds: 150));
      expect(controller.activeLineIndex, 2);
      expect(controller.isAdvancing, isTrue);
    }
    await update(200);
    expect(controller.position, const Duration(milliseconds: 200));

    // The floor also applies to direct display-frame reads.
    player.position = const Duration(milliseconds: 180);
    expect(source.position, const Duration(milliseconds: 200));
  });

  test(
    'pause, buffering and resume do not rewind the displayed time',
    () async {
      player.playing = true;
      await update(2100);
      player.playing = false;
      await update(1980);
      expect(controller.position, const Duration(milliseconds: 2100));
      expect(controller.isAdvancing, isFalse);
      player.playing = true;
      player.processingState = ProcessingState.buffering;
      await update(2000);
      expect(controller.position, const Duration(milliseconds: 2100));
      expect(controller.isAdvancing, isFalse);
      player.processingState = ProcessingState.ready;
      await update(2050);
      expect(controller.position, const Duration(milliseconds: 2100));
      await update(2200);
      expect(controller.position, const Duration(milliseconds: 2200));
    },
  );

  test(
    'backward seeks and replay reset the floor, even while paused',
    () async {
      for (final playing in [true, false]) {
        player.playing = playing;
        await update(5000);
        player.emitSeek(50);
        await Future<void>.delayed(Duration.zero);
        expect(controller.position, const Duration(milliseconds: 50));
        expect(controller.activeLineIndex, 1);
        player.emitSeek(0);
        await Future<void>.delayed(Duration.zero);
        expect(controller.position, Duration.zero);
        expect(controller.activeLineIndex, 0);
      }
    },
  );

  test(
    'loading, replacing a source and changing track reset the floor',
    () async {
      await update(5000);
      player.processingState = ProcessingState.loading;
      await update(0);
      expect(controller.position, Duration.zero);
      player.processingState = ProcessingState.ready;
      await update(100);
      expect(controller.position, const Duration(milliseconds: 100));
      await update(5000);
      player.currentIndex = 1;
      await update(0);
      expect(controller.position, Duration.zero);
      await update(5000);
      player.audioSource = AudioSource.uri(Uri.parse('asset:///other.mp3'));
      await update(0);
      expect(controller.position, Duration.zero);
    },
  );

  test('a new track drops the old position reported during loading', () async {
    await update(40000);
    player.audioSource = AudioSource.uri(Uri.parse('asset:///other.mp3'));
    player.processingState = ProcessingState.loading;
    await update(40000);
    expect(source.position, const Duration(seconds: 40));
    player.processingState = ProcessingState.ready;
    await update(0);
    expect(controller.position, Duration.zero);
    await update(100);
    expect(controller.position, const Duration(milliseconds: 100));
  });

  test(
    'shared listeners retain the floor and detach all subscriptions',
    () async {
      await update(150);
      player.position = Duration.zero;
      final second = LyricController(progressSource: source);
      expect(second.position, const Duration(milliseconds: 150));
      second.dispose();
      await update(100);
      expect(controller.position, const Duration(milliseconds: 150));
      expect(player.updates.hasListener, isTrue);
      expect(player.jumps.hasListener, isTrue);
      controller.progressSource = null;
      expect(player.updates.hasListener, isFalse);
      expect(player.jumps.hasListener, isFalse);
      player.emitSeek(50);
      controller.progressSource = source;
      expect(controller.position, const Duration(milliseconds: 50));
    },
  );
}
