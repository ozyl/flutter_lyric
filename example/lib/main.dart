import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_lyric/lyric_controller.dart';
import 'package:flutter_lyric/lyric_util.dart';
import 'package:flutter_lyric/lyric_widget.dart';

void main() => runApp(MyApp());

class MyApp extends StatelessWidget {
  // This widget is the root of your application.

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Lyric Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: MyHomePage(title: 'Flutter Lyric'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  MyHomePage({Key key, this.title}) : super(key: key);

  final String title;

  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> with TickerProviderStateMixin {
  var songLyc =
//      "[ti:告白气球] [ar:周杰伦] [al:周杰伦的床边故事] [by:] [offset:0] [00:00.00]告白气球 - 周杰伦 (Jay Chou) [00:07.86]词：方文山 [00:15.72]曲：周杰伦 [00:23.59]塞纳河畔 左岸的咖啡 [00:26.16]我手一杯 品尝你的美 [00:28.78] [00:29.33]留下唇印的嘴 [00:31.83] [00:34.27]花店玫瑰 名字写错谁 [00:36.90]告白气球 风吹到对街 [00:39.29] [00:40.01]微笑在天上飞 [00:42.10] [00:44.01]你说你有点难追,我是增加的歌词啦啦啦亮啊拉亮啊塞弗，阿马塞洛翻领埃及饭狂爱经翻领爱啦 [00:46.57]想让我知难而退 [00:49.22]礼物不需挑最贵 [00:51.89]只要香榭的落叶 [00:54.56]喔 营造浪漫的约会 [00:57.26]不害怕搞砸一切 [00:59.93]拥有你就拥有全世界 [01:04.10] [01:05.01]亲爱的 爱上你 [01:08.17]从那天起 [01:10.61] [01:11.33]甜蜜的很轻易 [01:14.43] [01:15.69]亲爱的 别任性 [01:18.85]你的眼睛 [01:21.24] [01:21.94]在说我愿意 [01:25.23] [01:48.90]塞纳河畔 左岸的咖啡 [01:51.46]我手一杯 品尝你的美 [01:54.43]留下唇印的嘴 [01:56.63] [01:59.56]花店玫瑰 名字写错谁 [02:02.14]告白气球 风吹到对街 [02:04.37] [02:05.23]微笑在天上飞 [02:07.49] [02:09.29]你说你有点难追 [02:11.90]想让我知难而退 [02:14.60]礼物不需挑最贵 [02:17.26]只要香榭的落叶 [02:19.93]喔 营造浪漫的约会 [02:22.65]不害怕搞砸一切 [02:25.27]拥有你就拥有 全世界 [02:29.23] [02:30.31]亲爱的 爱上你 [02:33.58]从那天起 [02:36.03] [02:36.60]甜蜜的很轻易 [02:39.65] [02:40.94]亲爱的 别任性 [02:44.20]你的眼睛 [02:46.70] [02:47.26]在说我愿意 [02:50.81] [02:51.76]亲爱的 爱上你 [02:54.52] [02:55.05]恋爱日记 [02:57.30] [02:57.93]飘香水的回忆 [03:00.72] [03:02.33]一整瓶 的梦境 [03:05.42]全都有你 [03:07.91] [03:08.64]搅拌在一起 [03:11.39] [03:13.02]亲爱的别任性 [03:16.23]你的眼睛 [03:19.99] [03:21.31]在说我愿意";
      "[00:00.000] 作曲 : Maynard Plant/Blaise Plant/菊池拓哉 增加歌词测试越出屏幕。。。。。。。。。。。。。。。\n[00:00.226] 作词 : Maynard Plant/Blaise Plant/菊池拓哉\n[00:00.680]明日を照らすよSunshine\n[00:03.570]窓から射し込む…扉開いて\n[00:20.920]Stop!'cause you got me thinking\n[00:22.360]that I'm a little quicker\n[00:23.520]Go!Maybe the rhythm's off,\n[00:25.100]but I will never let you\n[00:26.280]Know!I wish that you could see it for yourself.\n[00:28.560]It's not,it's not,just stop,hey y'all!やだ!\n[00:30.930]I never thought that I would take over it all.\n[00:33.420]And now I know that there's no way I could fall.\n[00:35.970]You know it's on and on and off and on,\n[00:38.210]And no one gets away.\n[00:40.300]僕の夢は何処に在るのか?\n[00:45.100]影も形も見えなくて\n[00:50.200]追いかけていた守るべきもの\n[00:54.860]There's a sunshine in my mind\n[01:02.400]明日を照らすよSunshineどこまでも続く\n[01:07.340]目の前に広がるヒカリの先へ\n[01:12.870]未来の\n[01:15.420]輝く\n[01:18.100]You know it's hard,just take a chance.\n[01:19.670]信じて\n[01:21.289]明日も晴れるかな?\n[01:32.960]ほんの些細なことに何度も躊躇ったり\n[01:37.830]誰かのその言葉いつも気にして\n[01:42.850]そんな弱い僕でも「いつか必ずきっと!」\n[01:47.800]強がり?それも負け惜しみ?\n[01:51.940]僕の夢は何だったのか\n[01:56.720]大事なことも忘れて\n[02:01.680]目の前にある守るべきもの\n[02:06.640]There's a sunshine in my mind\n[02:14.500]明日を照らすよSunshineどこまでも続く\n[02:19.000]目の前に広がるヒカリの先へ\n[02:24.670]未来のSunshine\n[02:27.200]輝くSunshine\n[02:29.900]You know it's hard,just take a chance.\n[02:31.420]信じて\n[02:33.300]明日も晴れるかな?\n[02:47.200]Rain's got me now\n[03:05.650]I guess I'm waiting for that Sunshine\n[03:09.200]Why's It only shine in my mind\n[03:15.960]I guess I'm waiting for that Sunshine\n[03:19.110]Why's It only shine in my mind\n[03:25.970]明日を照らすよSunshineどこまでも続く\n[03:30.690]目の前に広がるヒカリの先へ\n[03:36.400]未来のSunshine\n[03:38.840]輝くSunshine\n[03:41.520]You know it's hard,just take a chance.\n[03:43.200]信じて\n[03:44.829]明日も晴れるかな?\n";
  var remarkSongLyc =
      "[00:00.680]照亮明天的阳光\n[00:03.570]从窗外洒进来…敞开门扉\n[00:20.920]停下!因为你让我感觉到\n[00:22.360]自己有点过快\n[00:23.520]走吧!也许脱离了节奏\n[00:25.100]但我绝不放开你\n[00:26.280]知道吗!我希望你能亲自看看\n[00:28.560]不是这样不是这样快停下听好!糟了!\n[00:30.930]我从来没想过我会接受这一切\n[00:33.420]现在我知道我没办法降低速度\n[00:35.970]你知道这是不断地和不时地\n[00:38.210]于是谁也无法逃脱\n[00:40.300]我的梦想究竟落在何方?\n[00:45.100]为何形影不见\n[00:50.200]奋力追赶着应当守护的事物\n[00:54.860]阳光至始至终都在我心底里\n[01:02.400]照亮明天的阳光无限延伸\n[01:07.340]向着展现眼前的光明前路\n[01:12.870]Sunshine未来的阳光\n[01:15.420]Sunshine耀眼的阳光\n[01:18.100]你知道难以达成只是想去尝试一番\n[01:19.670]相信吧\n[01:21.289]明天也会放晴吗?\n[01:32.960]常因些微不足道的事情踌躇不前\n[01:37.830]总是很在意某人说过的话\n[01:42.850]如此脆弱的我亦坚信「早日必定成功!」\n[01:47.800]这是逞强还是不服输?\n[01:51.940]我的梦想实为何物\n[01:56.720]竟忘了如此重要的事\n[02:01.680]应当守护的事物就在眼前\n[02:06.640]阳光至始至终都在我心底里\n[02:14.500]照亮明天的阳光无限延伸\n[02:19.000]向着展现眼前的光明前路\n[02:24.670]未来的阳光\n[02:27.200]耀眼的阳光\n[02:29.900]你知道难以达成只是想去尝试一番\n[02:31.420]相信吧\n[02:33.300]明天也会放晴吗?\n[02:47.200]此刻雨水纷飞\n[03:05.650]我推测我所等待的就是这缕阳光\n[03:09.200]为什么它只在我心中闪烁\n[03:15.960]我推测我所等待的就是这缕阳光\n[03:19.110]为什么它只在我心中闪烁\n[03:25.970]照亮明天的阳光无限延伸\n[03:30.690]向着展现眼前的光明前路\n[03:36.400]未来的阳光\n[03:38.840]耀眼的阳光\n[03:41.520]你知道难以达成只是想去尝试一番\n[03:43.200]相信吧\n[03:44.829]明天也会放晴吗?";
  bool showSelect = false;
  Duration start = new Duration(seconds: 0);
  LyricController controller;

  @override
  void initState() {
    controller = LyricController(vsync: this);
    controller.addListener(() {
      if (showSelect != controller.isDragging) {
        setState(() {
          showSelect = controller.isDragging;
        });
      }
    });
    super.initState();
  }

  double slider = 0;

  @override
  Widget build(BuildContext context) {
    var lyrics = LyricUtil.formatLyric(songLyc);
    var remarkLyrics = LyricUtil.formatLyric(remarkSongLyc);
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: SafeArea(
        child: Column(
          children: <Widget>[
            Expanded(
              child: Stack(
                alignment: Alignment.center,
                children: <Widget>[
                  Center(
                      child: LyricWidget(
                    size: Size(double.infinity, double.infinity),
                    lyrics: lyrics,
                    controller: controller,
                    remarkLyrics: remarkLyrics,
                  )),
                  Offstage(
                    offstage: !showSelect,
                    child: GestureDetector(
                      onTap: () {
                        controller.draggingComplete();
                        print("进度:${controller.draggingDuration}");
                      },
                      child: Row(
                        children: <Widget>[
                          Icon(
                            Icons.play_circle_outline,
                            color: Colors.green,
                          ),
                          Expanded(
                              child: Divider(
                            color: Colors.red,
                          )),
                        ],
                      ),
                    ),
                  )
                ],
              ),
            ),
            Slider(
              onChanged: (d) {
                setState(() {
                  slider = d;
                });
              },
              onChangeEnd: (d) {
                controller.progress = Duration(seconds: d.toInt());
              },
              value: slider,
              max: 320,
              min: 0,
            )
          ],
        ),
      ),
    );
  }
}
