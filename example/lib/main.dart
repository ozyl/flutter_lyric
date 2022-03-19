import 'dart:ui';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_lyric/lyrics_reader.dart';

import 'const.dart';

void main() {
  runApp(MaterialApp(home: MyApp()));
}

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with SingleTickerProviderStateMixin {
  AudioCache audioCache = AudioCache();
  AudioPlayer? audioPlayer;
  double sliderProgress = 0;
  double playProgress = 0;
  double max_value = 100;
  bool isTap = false;

  var lyricModel = LyricsModelBuilder.creat()
      .bindLyricToMain(normalLyric)
      .bindLyricToExt(transLyric)
      .getModel();

  var lyricUI = UINetease();

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Plugin example app'),
      ),
      body: buildContainer(),
    );
  }

  Widget buildContainer() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          child: buildReaderWidget(),
          height: MediaQuery.of(context).size.height / 2,
        ),
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              children: [
                ...buildPlayControl(),
                ...buildUIControl(),
              ],
            ),
          ),
        ),
      ],
    );
  }

  var lyricPadding = 40.0;
  Stack buildReaderWidget() {
    return Stack(
      children: [
        ...buildReaderBackground(),
        LyricsReader(
          padding: EdgeInsets.symmetric(horizontal: lyricPadding),
          model: lyricModel,
          position: playProgress,
          lyricUi: lyricUI,
          selectLineBuilder: (progress, confirm) {
            return Row(
              children: [
                IconButton(
                    onPressed: () {
                      LyricsLog.logD("点击事件");
                      confirm.call();
                      setState(() {
                        audioPlayer?.seek(Duration(milliseconds: progress));
                      });
                    },
                    icon: Icon(Icons.play_arrow, color: Colors.green)),
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(color: Colors.green),
                    height: 1,
                    width: double.infinity,
                  ),
                ),
                Text(
                  progress.toString(),
                  style: TextStyle(color: Colors.green),
                )
              ],
            );
          },
        )
      ],
    );
  }

  List<Widget> buildPlayControl() {
    return [
      if (kIsWeb == true)
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Text(
            "example's audio player library has problem in web platform,can't get music duration,you can use myself audio player library!",
            style: TextStyle(fontSize: 20, color: Colors.grey),
          ),
        ),
      Text(
        "播放进度$sliderProgress",
        style: TextStyle(
          fontSize: 16,
          color: Colors.green,
        ),
      ),
      if (sliderProgress < max_value)
        Slider(
          min: 0,
          max: max_value,
          label: sliderProgress.toString(),
          value: sliderProgress,
          activeColor: Colors.blueGrey,
          inactiveColor: Colors.blue,
          onChanged: (double value) {
            setState(() {
              sliderProgress = value;
            });
          },
          onChangeStart: (double value) {
            isTap = true;
          },
          onChangeEnd: (double value) {
            isTap = false;
            playProgress = value;
            audioPlayer?.seek(Duration(milliseconds: value.toInt()));
          },
        ),
      Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          TextButton(
              onPressed: () async {
                if (audioPlayer == null) {
                  audioPlayer = await audioCache.play("music1.mp3");
                  audioPlayer?.onDurationChanged.listen((Duration event) {
                    setState(() {
                      max_value = event.inMilliseconds.toDouble();
                    });
                  });
                  audioPlayer?.onAudioPositionChanged.listen((Duration event) {
                    if (isTap) return;
                    setState(() {
                      sliderProgress = event.inMilliseconds.toDouble();
                      playProgress = sliderProgress;
                    });
                  });
                } else {
                  audioPlayer?.resume();
                }
              },
              child: Text("播放歌曲")),
          Container(
            width: 10,
          ),
          TextButton(
              onPressed: () async {
                audioPlayer?.pause();
              },
              child: Text("暂停播放")),
          Container(
            width: 10,
          ),
          TextButton(
              onPressed: () async {
                audioPlayer?.stop();
                audioPlayer = null;
              },
              child: Text("停止播放")),
        ],
      ),
    ];
  }

  List<Widget> buildReaderBackground() {
    return [
      Positioned.fill(
        child: Image.asset(
          "bg.jpeg",
          fit: BoxFit.cover,
        ),
      ),
      Positioned.fill(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            color: Colors.black.withOpacity(0.3),
          ),
        ),
      )
    ];
  }

  var mainTextSize = 18.0;
  var extTextSize = 16.0;
  var lineGap = 16.0;
  var inlineGap = 10.0;
  var lyricAlign = LyricAlign.CENTER;

  List<Widget> buildUIControl() {
    return [
      Container(
        height: 30,
      ),
      Text("UI控制", style: TextStyle(fontWeight: FontWeight.bold)),
      buildTitle("歌词padding"),
      Slider(
        min: 0,
        max: 100,
        label: lyricPadding.toString(),
        value: lyricPadding,
        activeColor: Colors.blueGrey,
        inactiveColor: Colors.blue,
        onChanged: (double value) {
          setState(() {
            lyricPadding = value;
          });
        },
      ),
      buildTitle("主歌词大小"),
      Slider(
        min: 15,
        max: 30,
        label: mainTextSize.toString(),
        value: mainTextSize,
        activeColor: Colors.blueGrey,
        inactiveColor: Colors.blue,
        onChanged: (double value) {
          setState(() {
            mainTextSize = value;
          });
        },
        onChangeEnd: (double value) {
          setState(() {
            lyricUI.defaultSize = mainTextSize;
            refreshLyric();
          });
        },
      ),
      buildTitle("副歌词大小"),
      Slider(
        min: 15,
        max: 30,
        label: extTextSize.toString(),
        value: extTextSize,
        activeColor: Colors.blueGrey,
        inactiveColor: Colors.blue,
        onChanged: (double value) {
          setState(() {
            extTextSize = value;
          });
        },
        onChangeEnd: (double value) {
          setState(() {
            lyricUI.defaultExtSize = extTextSize;
            refreshLyric();
          });
        },
      ),
      buildTitle("行间距大小"),
      Slider(
        min: 10,
        max: 80,
        label: lineGap.toString(),
        value: lineGap,
        activeColor: Colors.blueGrey,
        inactiveColor: Colors.blue,
        onChanged: (double value) {
          setState(() {
            lineGap = value;
          });
        },
        onChangeEnd: (double value) {
          setState(() {
            lyricUI.lineGap = lineGap;
            refreshLyric();
          });
        },
      ),
      buildTitle("主副歌词间距大小"),
      Slider(
        min: 10,
        max: 80,
        label: inlineGap.toString(),
        value: inlineGap,
        activeColor: Colors.blueGrey,
        inactiveColor: Colors.blue,
        onChanged: (double value) {
          setState(() {
            inlineGap = value;
          });
        },
        onChangeEnd: (double value) {
          setState(() {
            lyricUI.inlineGap = inlineGap;
            refreshLyric();
          });
        },
      ),
      buildTitle("歌词对齐方向"),
      Row(
        mainAxisSize: MainAxisSize.min,
        children: LyricAlign.values
            .map((e) => Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Column(
                    children: [
                      Radio<LyricAlign>(
                          activeColor: Colors.orangeAccent,
                          value: e,
                          groupValue: lyricAlign,
                          onChanged: (v) {
                            setState(() {
                              lyricAlign = v!;
                              lyricUI.lyricAlign = lyricAlign;
                              refreshLyric();
                            });
                          }),
                      Text(e.toString().split(".")[1])
                    ],
                  ),
                ))
            .toList(),
      ),
      buildTitle("选择行偏移"),
      Slider(
        min: 0.3,
        max: 0.8,
        label: bias.toString(),
        value: bias,
        activeColor: Colors.blueGrey,
        inactiveColor: Colors.blue,
        onChanged: (double value) {
          setState(() {
            bias = value;
          });
        },
        onChangeEnd: (double value) {
          setState(() {
            lyricUI.bias = bias;
            refreshLyric();
          });
        },
      ),
      buildTitle("选择行基线"),
      Row(
        mainAxisSize: MainAxisSize.min,
        children: LyricBaseLine.values
            .map((e) => Expanded(
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Column(
                  children: [
                    Radio<LyricBaseLine>(
                    activeColor: Colors.orangeAccent,
                    value: e,
                    groupValue: lyricBiasBaseLine,
                    onChanged: (v) {
                      setState(() {
                        lyricBiasBaseLine = v!;
                        lyricUI.lyricBaseLine = lyricBiasBaseLine;
                        refreshLyric();
                      });
                    }),
                    Text(e.toString().split(".")[1])
                  ],
                ),
              ),
            ))
            .toList(),
      ),
    ];
  }

  void refreshLyric() {
    lyricUI = UINetease.clone(lyricUI);
  }

  var bias = 0.5;
  var lyricBiasBaseLine = LyricBaseLine.CENTER;

  Text buildTitle(String title) => Text(title,
      style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green));
}
