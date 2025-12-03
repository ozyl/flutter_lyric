import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_lyric/flutter_lyric.dart';
import 'package:flutter_lyric_example/show_lyric.dart';
import 'package:just_audio/just_audio.dart';

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
  final player = AudioPlayer();

  ValueNotifier<Duration> progressNotifier = ValueNotifier(Duration.zero);

  @override
  void initState() {
    super.initState();
    setPlayer();
    player.positionStream.listen((event) {
      progressNotifier.value = event;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Builder(
        builder: (context) {
          return AnnotatedRegion(
            value: SystemUiOverlayStyle(
              systemNavigationBarColor: Colors.transparent,
              systemNavigationBarDividerColor: Colors.transparent,
              systemNavigationBarIconBrightness: Brightness.light,
              statusBarColor: Colors.transparent,
            ),
            child: Scaffold(
              extendBody: true,
              body: Stack(
                clipBehavior: Clip.hardEdge,
                children: [
                  Positioned.fill(
                    child: ClipPath(
                      clipBehavior: Clip.hardEdge,
                      child: ImageFiltered(
                        imageFilter: ImageFilter.blur(sigmaX: 120, sigmaY: 120),
                        child: Transform.scale(
                          scale: 1.8,
                          child: Image.asset(
                            'assets/cover.webp',
                            width: double.infinity,
                            height: double.infinity,
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                    ),
                  ),
                  Positioned.fill(
                    child: Column(
                      children: [
                        SizedBox(height: MediaQuery.paddingOf(context).top),
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 16.0),
                          child: DefaultTextStyle(
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.white.withValues(alpha: 0.8),
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  "Be What You Wanna Be",
                                  style: TextStyle(fontWeight: FontWeight.w600),
                                ),
                                SizedBox(height: 4),
                                Text("Darin", style: TextStyle(fontSize: 12)),
                              ],
                            ),
                          ),
                        ),
                        Expanded(
                          child: ValueListenableBuilder(
                            valueListenable: progressNotifier,
                            builder: (context, value, child) {
                              final items = [
                                ShowLyric(
                                  initStyle: LyricStyles.default2,
                                  initController: (controller) {
                                    controller.setOnTapLineCallback(
                                      (duration) async => {
                                        controller.stopSelection(),
                                        await player.seek(duration),
                                        player.play(),
                                      },
                                    );
                                  },
                                  progress: value,
                                  afterLyricBuilder: (lyricController, style) =>
                                      [
                                        LyricSelectionProgress2(
                                          controller: lyricController,
                                          onPlay: (SelectionState state) async {
                                            lyricController.stopSelection();
                                            await player.seek(state.duration);
                                            player.play();
                                          },
                                          style: style,
                                        ),
                                      ],
                                ),
                                ShowLyric(
                                  initStyle: LyricStyles.default1,
                                  progress: value,
                                  beforeLyricBuilder:
                                      (lyricController, style) => [
                                        LyricSelectionContentBackground(
                                          controller: lyricController,
                                          style: style,
                                        ),
                                      ],
                                  afterLyricBuilder: (lyricController, style) =>
                                      [
                                        LyricSelectionProgress(
                                          controller: lyricController,
                                          onPlay: (SelectionState state) async {
                                            lyricController.stopSelection();
                                            await player.seek(state.duration);
                                            player.play();
                                          },
                                          style: style,
                                        ),
                                      ],
                                ),
                                ShowLyric(
                                  initStyle: LyricStyles.single,
                                  progress: value,
                                ),
                              ];
                              return ConstrainedBox(
                                constraints: BoxConstraints(maxWidth: 1200),
                                child: Flex(
                                  direction:
                                      MediaQuery.sizeOf(context).width > 500
                                      ? Axis.horizontal
                                      : Axis.vertical,
                                  children: items
                                      .map((e) => Expanded(child: e))
                                      .toList(),
                                ),
                              );
                            },
                          ),
                        ),
                        buildControl(),
                        SizedBox(height: MediaQuery.paddingOf(context).bottom),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  double? _dragValue;

  Widget buildControl() {
    return Builder(
      builder: (context) {
        final theme = Theme.of(context);
        return Theme(
          data: theme.copyWith(
            iconTheme: theme.iconTheme.copyWith(
              color: theme.colorScheme.primary,
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SliderTheme(
                      data: SliderThemeData(
                        trackHeight: 1,
                        trackShape: RectangularSliderTrackShape(),
                        thumbShape: RoundSliderThumbShape(
                          enabledThumbRadius: 8,
                        ),
                        overlayShape: RoundSliderOverlayShape(
                          overlayRadius: 10,
                        ),
                        activeTrackColor: Colors.white,
                        inactiveTrackColor: Colors.white.withValues(alpha: 0.2),
                      ),
                      child: StreamBuilder(
                        stream: player.durationStream,
                        builder: (context, snapshot) {
                          return StreamBuilder(
                            stream: player.positionStream,
                            builder: (context, asyncSnapshot) {
                              return Slider(
                                value:
                                    _dragValue ??
                                    asyncSnapshot.data?.inSeconds.toDouble() ??
                                    0,
                                max: musicDuration.inSeconds.toDouble(),
                                onChangeEnd: (v) => {
                                  player.seek(Duration(seconds: v.toInt())),
                                  setState(() {
                                    _dragValue = null;
                                  }),
                                },
                                onChangeStart: (value) => setState(() {
                                  _dragValue = value;
                                }),
                                onChanged: (value) => setState(() {
                                  _dragValue = value;
                                }),
                              );
                            },
                          );
                        },
                      ),
                    ),
                    DefaultTextStyle(
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.white.withValues(alpha: 0.7),
                        height: 1,
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8.0,
                          vertical: 0,
                        ),
                        child: Builder(
                          builder: (context) {
                            Widget buildText(inSeconds) {
                              return Text(
                                inSeconds == null
                                    ? '00:00'
                                    : '${(inSeconds ~/ 60).toString().padLeft(2, '0')}:${(inSeconds % 60).toInt().toString().padLeft(2, '0')}',
                              );
                            }

                            return Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                StreamBuilder(
                                  stream: player.positionStream,
                                  builder: (context, asyncSnapshot) {
                                    final inSeconds =
                                        _dragValue ??
                                        asyncSnapshot.data?.inSeconds;
                                    return buildText(inSeconds);
                                  },
                                ),
                                StreamBuilder(
                                  stream: player.durationStream,
                                  builder:
                                      (
                                        context,
                                        AsyncSnapshot<Duration?> asyncSnapshot,
                                      ) {
                                        final inSeconds =
                                            asyncSnapshot.data?.inSeconds;

                                        return buildText(inSeconds);
                                      },
                                ),
                              ],
                            );
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(width: 12),
              StreamBuilder(
                stream: player.playerStateStream,
                builder: (context, AsyncSnapshot<PlayerState> asyncSnapshot) {
                  return StreamBuilder(
                    stream: player.playingStream,
                    builder:
                        (BuildContext context, AsyncSnapshot<bool> snapshot) {
                          final isCompleted =
                              asyncSnapshot.data?.processingState ==
                              ProcessingState.completed;
                          final isPlaying = isCompleted
                              ? false
                              : snapshot.data ?? false;
                          return GestureDetector(
                            onTap: () {
                              if (isPlaying) {
                                player.pause();
                              } else {
                                if (isCompleted) {
                                  player.seek(Duration.zero);
                                }
                                player.play();
                              }
                            },
                            child: Icon(
                              isPlaying
                                  ? CupertinoIcons.pause_circle_fill
                                  : CupertinoIcons.play_circle_fill,
                              size: 32,
                            ),
                          );
                        },
                  );
                },
              ),
              SizedBox(width: 12),
            ],
          ),
        );
      },
    );
  }

  Duration musicDuration = Duration.zero;

  void setPlayer() async {
    musicDuration = await player.setAsset('assets/music.mp3') ?? Duration.zero;
  }
}
