// @dart=3.8

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_lyric/flutter_lyric.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_media_kit/just_audio_media_kit.dart';
import 'demo_songs.dart';
import 'just_audio_progress_source.dart';
import 'playback_controls.dart';
import 'studio.dart';
import 'studio_theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // AVPlayer can block the macOS main thread while querying time after an
  // output device disconnects. Use libmpv for this desktop demo's audio.
  JustAudioMediaKit.ensureInitialized(
    macOS: true,
    linux: false,
    windows: false,
  );
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key, this.player});
  final AudioPlayer? player;
  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late final _player = widget.player ?? AudioPlayer();
  late final _controller = LyricController(
    progressSource: JustAudioProgressSource(_player),
  );
  DemoSong _song = beWhatYouWannaBe;
  bool _loading = true;
  String? _error;
  Duration _duration = Duration.zero;
  StreamSubscription<PlayerException>? _audioErrors;

  @override
  void initState() {
    super.initState();
    _audioErrors = _player.errorStream.listen((_) {
      if (mounted && !_loading) {
        setState(() => _error = '音频播放出错，请检查声音输出后重试');
      }
    });
    unawaited(_load(_song));
  }

  Future<void> _load(DemoSong song) async {
    final resume =
        _player.playing && _player.processingState != ProcessingState.completed;
    setState(() {
      _song = song;
      _loading = true;
      _error = null;
      _duration = Duration.zero;
    });
    _controller.clear();
    try {
      // Replacing a playlist in just_audio_web can reuse the first source's
      // cached player. Release that backend before loading the selected song.
      await _player.stop();
      final document = await song.loadLyrics();
      if (!mounted) return;
      final duration = await _player.setAsset(
        song.audioAsset,
        initialPosition: Duration.zero,
      );
      if (!mounted) return;
      _controller.loadDocument(document);
      setState(() {
        _duration = duration ?? Duration.zero;
        _loading = false;
      });
      if (resume) unawaited(_play());
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = '歌曲加载失败，请重试';
        });
      }
    }
  }

  void _selectSong(DemoSong song) {
    if (_loading || song == _song) return;
    unawaited(_load(song));
  }

  Future<void> _play() async {
    try {
      await _player.play();
    } catch (_) {
      if (mounted) setState(() => _error = '播放未能开始，请重试');
    }
  }

  Future<void> _seek(Duration position, {bool play = false}) async {
    if (_loading || _error != null) return;
    try {
      await _player.seek(position);
      if (play && mounted) unawaited(_play());
    } catch (_) {
      if (mounted) setState(() => _error = '跳转失败，请重试');
    }
  }

  Future<void> _toggle() async {
    if (_loading || _error != null) return;
    try {
      if (_player.playing &&
          _player.processingState != ProcessingState.completed) {
        await _player.pause();
      } else {
        if (_player.processingState == ProcessingState.completed) {
          await _seek(Duration.zero);
        }
        unawaited(_play());
      }
    } catch (_) {
      if (mounted) setState(() => _error = '播放控制失败，请重试');
    }
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    title: 'Lyric Studio · 歌词工作室',
    theme: studioTheme(),
    home: AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
      child: LyricStudio(
        controller: _controller,
        onLineTap: (details) =>
            unawaited(_seek(details.seekPosition, play: true)),
        onTogglePlayback: () => unawaited(_toggle()),
        playback: StreamBuilder<PlayerState>(
          stream: _player.playerStateStream,
          builder: (context, state) => StreamBuilder<Duration>(
            stream: _player.positionStream,
            builder: (context, _) => PlaybackControls(
              key: ValueKey(_song.id),
              song: _song,
              onSongSelected: _selectSong,
              position: _loading ? Duration.zero : _controller.position,
              duration: _duration,
              playing:
                  (state.data?.playing ?? false) &&
                  state.data?.processingState != ProcessingState.completed,
              loading: _loading,
              error: _error,
              onRetry: () => unawaited(_load(_song)),
              onPlay: () => unawaited(_toggle()),
              onSeek: (value) => unawaited(_seek(value)),
            ),
          ),
        ),
      ),
    ),
  );

  @override
  void dispose() {
    unawaited(_audioErrors?.cancel());
    _controller.dispose();
    unawaited(_player.dispose());
    super.dispose();
  }
}
