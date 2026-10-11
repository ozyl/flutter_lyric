import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_lyric/flutter_lyric.dart';
import 'package:just_audio/just_audio.dart';
import 'just_audio_progress_source.dart';
import 'mock.dart';
import 'playback_controls.dart';
import 'studio.dart';
import 'studio_theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});
  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final _player = AudioPlayer();
  late final _controller = LyricController(
    progressSource: JustAudioProgressSource(_player),
  )..load(qrc, translation: tlrc);
  bool _loading = true;
  String? _error;
  Duration _duration = Duration.zero;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final duration = await _player.setAsset('assets/music.mp3');
      if (!mounted) return;
      setState(() {
        _duration = duration ?? Duration.zero;
        _loading = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = '音频加载失败，请重试';
        });
      }
    }
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
    if (_player.playing &&
        _player.processingState != ProcessingState.completed) {
      await _player.pause();
    } else {
      if (_player.processingState == ProcessingState.completed) {
        await _seek(Duration.zero);
      }
      unawaited(_play());
    }
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    title: 'Lyric Studio · 歌词实验室',
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
            builder: (context, position) => PlaybackControls(
              position: position.data ?? Duration.zero,
              duration: _duration,
              playing:
                  (state.data?.playing ?? false) &&
                  state.data?.processingState != ProcessingState.completed,
              loading: _loading,
              error: _error,
              onRetry: _load,
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
    _controller.dispose();
    unawaited(_player.dispose());
    super.dispose();
  }
}
