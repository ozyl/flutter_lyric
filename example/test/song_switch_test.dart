// @dart=3.8

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_lyric/flutter_lyric.dart';
import 'package:flutter_lyric/src/model/lyric_gap.dart';
import 'package:flutter_lyric/src/rendering/lyric_viewport.dart';
import 'package:flutter_lyric_example/demo_songs.dart';
import 'package:flutter_lyric_example/main.dart';
import 'package:flutter_lyric_example/playback_controls.dart';
import 'package:flutter_lyric_example/preset_gallery.dart';
import 'package:flutter_lyric_example/studio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:just_audio/just_audio.dart';

RenderLyricViewport countdownViewport(WidgetTester tester) =>
    tester.renderObject<RenderLyricViewport>(find.byType(LyricViewport));

class _Player implements AudioPlayer {
  final _states = StreamController<PlayerState>.broadcast(sync: true);
  final _positions = StreamController<Duration>.broadcast(sync: true);
  final _events = StreamController<PlayerEvent>.broadcast(sync: true);
  final _jumps = StreamController<PositionDiscontinuity>.broadcast(sync: true);
  final _errors = StreamController<PlayerException>.broadcast(sync: true);
  final assets = <String>[];
  Completer<void>? pendingLoad;

  @override
  Duration position = Duration.zero;
  @override
  bool playing = false;
  @override
  ProcessingState processingState = ProcessingState.idle;
  @override
  AudioSource? audioSource;
  @override
  int? get currentIndex => 0;
  @override
  Stream<PlayerState> get playerStateStream => _states.stream;
  @override
  Stream<Duration> get positionStream => _positions.stream;
  @override
  Stream<PlayerEvent> get playerEventStream => _events.stream;
  @override
  Stream<PositionDiscontinuity> get positionDiscontinuityStream =>
      _jumps.stream;
  @override
  Stream<PlayerException> get errorStream => _errors.stream;

  void _emit() {
    _events.add(PlayerEvent(playing: playing));
    _states.add(PlayerState(playing, processingState));
    _positions.add(position);
  }

  @override
  Future<Duration?> setAsset(
    String assetPath, {
    String? package,
    bool preload = true,
    Duration? initialPosition,
    dynamic tag,
  }) async {
    assets.add(assetPath);
    audioSource = AudioSource.uri(Uri.parse('asset:///$assetPath'));
    processingState = ProcessingState.loading;
    _emit();
    final pending = pendingLoad;
    pendingLoad = null;
    await pending?.future;
    position = initialPosition ?? position;
    processingState = ProcessingState.ready;
    _emit();
    return Duration(seconds: assetPath == stay.audioAsset ? 141 : 192);
  }

  @override
  Future<void> play() async {
    playing = true;
    _emit();
  }

  @override
  Future<void> pause() async {
    playing = false;
    _emit();
  }

  @override
  Future<void> seek(Duration? value, {int? index}) async {
    final previous = PlaybackEvent(updatePosition: position);
    position = value ?? Duration.zero;
    _emit();
    _jumps.add(
      PositionDiscontinuity(
        PositionDiscontinuityReason.seek,
        previous,
        PlaybackEvent(updatePosition: position),
      ),
    );
  }

  @override
  Future<void> dispose() async {
    await Future.wait([
      _states.close(),
      _positions.close(),
      _events.close(),
      _jumps.close(),
      _errors.close(),
    ]);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

PlaybackControls controls(WidgetTester tester) =>
    tester.widget<PlaybackControls>(find.byType(PlaybackControls));

Future<void> waitFor(WidgetTester tester, bool Function() condition) async {
  await tester.pump();
  for (var i = 0; i < 100 && !condition(); i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
    await tester.pump();
  }
  expect(condition(), isTrue);
  await tester.pump(const Duration(milliseconds: 500));
}

Future<_Player> _mount(WidgetTester tester, Size size) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final player = _Player();
  await tester.pumpWidget(MyApp(player: player));
  await waitFor(tester, () => !controls(tester).loading);
  expect(controls(tester).error, isNull);
  return player;
}

Future<void> select(WidgetTester tester, DemoSong song) async {
  await tester.ensureVisible(find.byKey(const ValueKey('song-selector')));
  await tester.tap(find.byKey(const ValueKey('song-selector')));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
  await tester.pump();
  await tester.tap(find.byKey(ValueKey('song-${song.id}')));
  await waitFor(tester, () => !controls(tester).loading);
}

// The default Apple Music preset has continuous Character Float repainting.
Future<void> pumpStudio(WidgetTester tester) async {
  await tester.pump();
  for (var frame = 0; frame < 75; frame++) {
    await tester.pump(const Duration(milliseconds: 16));
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'bundled songs load word timing, translations and audio assets',
    () async {
      expect(demoSongs, [beWhatYouWannaBe, stay]);
      for (final song in demoSongs) {
        final document = await song.loadLyrics();
        expect(document.lines, isNotEmpty);
        expect(
          document.lines.every((line) => line.words?.isNotEmpty ?? false),
          true,
        );
        expect(
          document.lines.any((line) => line.translation?.isNotEmpty ?? false),
          true,
        );
        expect(
          (await rootBundle.load(song.audioAsset)).lengthInBytes,
          greaterThan(0),
        );
      }
      expect((await stay.loadLyrics()).tags['ti'], stay.title);
      expect(
        (await stay.loadLyrics()).vocalStart,
        const Duration(milliseconds: 11438),
      );
    },
  );

  for (final (song, previousTs, startTs) in const [(stay, 7916, 11438)]) {
    test(
      '${song.title} has a full intro independent of credit timing',
      () async {
        final document = await song.loadLyrics();
        const config = LyricCountdown(breathDuration: Duration(minutes: 2));
        final timeline = LyricGapTimeline(document);
        final start = Duration(milliseconds: previousTs);
        final gap = timeline.at(Duration.zero, config)!;
        expect(gap.end - gap.start, Duration(milliseconds: startTs));
        expect(gap.start, Duration.zero);
        expect(timeline.at(start, config), same(gap));
        expect(document.lines[gap.nextIndex - 1].start, start);
        // Explicit credit ends nearly touch vocals, but do not shorten the gap.
        expect(
          (gap.end - document.lines[gap.nextIndex - 1].end!).inMilliseconds,
          lessThanOrEqualTo(10),
        );
      },
    );
    testWidgets('${song.title} intro countdown uses saved metadata', (
      tester,
    ) async {
      await _mount(tester, const Size(1600, 1000));
      await select(tester, song);
      final state = tester
          .widget<PresetGallery>(find.byType(PresetGallery))
          .state;
      state.update(state.preset.copyWith(countdown: const LyricCountdown()));
      controls(tester).onSeek(Duration(milliseconds: startTs - 3001));
      await pumpStudio(tester);
      expect(countdownViewport(tester).session.hasCountdown, isFalse);
      final view = tester
          .renderObject<RenderLyricViewport>(find.byType(LyricViewport))
          .session;
      final nextIndex = view.controller.document!.lines.indexWhere(
        (line) => line.start == Duration(milliseconds: startTs),
      );
      expect(
        view.lineRect(nextIndex).center.dy,
        greaterThan(state.preset.activeAnchor.resolve(view.size.height)),
      );
      controls(tester).onSeek(Duration(milliseconds: startTs - 3000));
      await pumpStudio(tester);
      expect(countdownViewport(tester).session.hasCountdown, isTrue);
      expect(view.countdownFrame!.gapStart, Duration.zero);
      expect(
        view.countdownFrame!.rect.center.dy,
        closeTo(state.preset.activeAnchor.resolve(view.size.height), .01),
      );
      expect(
        view.lineRect(nextIndex).top,
        greaterThan(view.countdownFrame!.rect.bottom),
      );
      controls(tester).onSeek(Duration(milliseconds: startTs));
      await pumpStudio(tester);
      expect(countdownViewport(tester).session.hasCountdown, isFalse);
      controls(tester).onSeek(Duration(milliseconds: startTs - 3000));
      await pumpStudio(tester);
      expect(countdownViewport(tester).session.hasCountdown, isTrue);
      await select(tester, beWhatYouWannaBe);
      await pumpStudio(tester);
      expect(countdownViewport(tester).session.hasCountdown, isFalse);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }

  for (final layoutMode in LyricLayoutMode.values) {
    testWidgets(
      'STAY countdown follows the lyric flow through credits in $layoutMode',
      (tester) async {
        await _mount(tester, const Size(1600, 1000));
        await select(tester, stay);
        final state = tester
            .widget<PresetGallery>(find.byType(PresetGallery))
            .state;
        state.update(
          state.preset.copyWith(
            layoutMode: layoutMode,
            lineMotion: LyricPresets.appleMusic.lineMotion,
            countdown: const LyricCountdown(
              breathDuration: Duration(seconds: 10),
            ),
          ),
        );
        final view = tester
            .renderObject<RenderLyricViewport>(find.byType(LyricViewport))
            .session;
        for (final timestamp in [6217, 7916]) {
          controls(tester).onSeek(Duration(milliseconds: timestamp - 1));
          await pumpStudio(tester);
          final anchor = state.preset.activeAnchor.resolve(view.size.height);
          controls(tester).onSeek(Duration(milliseconds: timestamp));
          await tester.pump();
          expect(
            view.controller.activeLine!.start,
            Duration(milliseconds: timestamp),
          );
          for (var sample = 0; sample < 45; sample++) {
            final frame = view.countdownFrame!;
            expect(
              frame.rect.bottom + state.preset.countdown.spacing,
              closeTo(view.lineRect(frame.nextIndex).top, .01),
            );
            await tester.pump(const Duration(milliseconds: 16));
          }
          await pumpStudio(tester);
          expect(view.countdownFrame!.rect.center.dy, closeTo(anchor, .01));
        }
        controls(tester).onSeek(const Duration(milliseconds: 11438));
        await pumpStudio(tester);
        expect(countdownViewport(tester).session.hasCountdown, isFalse);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }

  for (final size in [const Size(320, 568), const Size(1600, 1000)]) {
    testWidgets(
      'switching preserves playback, LRC preview and drafts at $size',
      (tester) async {
        final player = await _mount(tester, size);
        final parent = tester
            .widget<LyricStudio>(find.byType(LyricStudio))
            .controller;
        final state = tester
            .widget<PresetGallery>(find.byType(PresetGallery))
            .state;
        state.update(state.preset.copyWith(lineSpacing: 47));
        final draft = state.preset;
        await tester.tap(find.byKey(const ValueKey('timing-mode')));
        await pumpStudio(tester);
        await tester.tap(find.text('普通 LRC').last);
        await pumpStudio(tester);
        controls(tester).onSeek(const Duration(seconds: 40));
        await tester.pump();

        await select(tester, stay);
        expect(controls(tester).song, stay);
        expect(controls(tester).playing, false);
        expect(controls(tester).position, Duration.zero);
        expect(controls(tester).duration, const Duration(seconds: 141));
        expect(player.assets.last, stay.audioAsset);
        expect(parent.document!.tags['ti'], stay.title);
        expect(parent.document!.lines.first.words, isNotEmpty);
        expect(
          parent.document!.vocalStart,
          const Duration(milliseconds: 11438),
        );
        final preview = tester
            .widget<LyricView>(find.byType(LyricView))
            .controller;
        expect(preview.document!.tags['ti'], stay.title);
        expect(preview.document!.lines.first.words, isNull);
        expect(preview.document!.vocalStart, parent.document!.vocalStart);
        expect(state.preset, same(draft));
        expect(find.text(stay.title), findsOneWidget);

        controls(tester).onPlay();
        await tester.pump();
        expect(player.playing, true);
        await select(tester, beWhatYouWannaBe);
        expect(controls(tester).song, beWhatYouWannaBe);
        expect(controls(tester).playing, true);
        expect(controls(tester).position, Duration.zero);
        expect(parent.document!.tags['ar'], 'Darin');
        expect(parent.document!.vocalStart, isNull);
        expect(preview.document!.tags['ar'], 'Darin');
        expect(state.preset, same(draft));
        final loads = player.assets.length;
        controls(tester).onSongSelected!(beWhatYouWannaBe);
        expect(player.assets.length, loads);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }

  testWidgets('loading blocks commands and retry reloads the selected song', (
    tester,
  ) async {
    final player = await _mount(tester, const Size(390, 844));
    final pending = Completer<void>();
    player.pendingLoad = pending;
    controls(tester).onSongSelected!(stay);
    await waitFor(tester, () => player.assets.last == stay.audioAsset);
    expect(controls(tester).loading, true);
    expect(controls(tester).duration, Duration.zero);
    expect(
      tester
          .widget<PopupMenuButton<DemoSong>>(
            find.byKey(const ValueKey('song-selector')),
          )
          .enabled,
      false,
    );
    controls(tester).onSongSelected!(beWhatYouWannaBe);
    controls(tester).onPlay();
    controls(tester).onSeek(const Duration(seconds: 30));
    await tester.pump();
    expect(controls(tester).song, stay);
    expect(player.playing, false);
    expect(player.position, Duration.zero);
    pending.completeError(StateError('Audio load failed'));
    await waitFor(tester, () => !controls(tester).loading);
    expect(controls(tester).error, isNotNull);
    await tester.tap(find.text('重试'));
    await waitFor(tester, () => !controls(tester).loading);
    expect(controls(tester).error, isNull);
    expect(controls(tester).song, stay);
    expect(player.assets, [
      beWhatYouWannaBe.audioAsset,
      stay.audioAsset,
      stay.audioAsset,
    ]);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
