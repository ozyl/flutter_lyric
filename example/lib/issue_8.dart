import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'package:flutter_lyric/lyric_controller.dart';
import 'package:flutter_lyric/lyric_util.dart';
import 'package:flutter_lyric/lyric_widget.dart';

class Issue8 extends StatefulWidget {
  const Issue8({Key key}) : super(key: key);

  @override
  _Issue8State createState() => _Issue8State();
}

class _Issue8State extends State<Issue8> with TickerProviderStateMixin {
  var pageController = PageController();

  //歌词
  var songLyc =
      "[00:00.000] 作曲 : Maynard Plant/Blaise Plant/菊池拓哉 \n[00:00.226] 作词 : Maynard Plant/Blaise Plant/菊池拓哉\n[00:00.680]明日を照らすよSunshine\n[00:03.570]窓から射し込む…扉開いて\n[00:20.920]Stop!'cause you got me thinking\n[00:22.360]that I'm a little quicker\n[00:23.520]Go!Maybe the rhythm's off,\n[00:25.100]but I will never let you\n[00:26.280]Know!I wish that you could see it for yourself.\n[00:28.560]It's not,it's not,just stop,hey y'all!やだ!\n[00:30.930]I never thought that I would take over it all.\n[00:33.420]And now I know that there's no way I could fall.\n[00:35.970]You know it's on and on and off and on,\n[00:38.210]And no one gets away.\n[00:40.300]僕の夢は何処に在るのか?\n[00:45.100]影も形も見えなくて\n[00:50.200]追いかけていた守るべきもの\n[00:54.860]There's a sunshine in my mind\n[01:02.400]明日を照らすよSunshineどこまでも続く\n[01:07.340]目の前に広がるヒカリの先へ\n[01:12.870]未来の\n[01:15.420]輝く\n[01:18.100]You know it's hard,just take a chance.\n[01:19.670]信じて\n[01:21.289]明日も晴れるかな?\n[01:32.960]ほんの些細なことに何度も躊躇ったり\n[01:37.830]誰かのその言葉いつも気にして\n[01:42.850]そんな弱い僕でも「いつか必ずきっと!」\n[01:47.800]強がり?それも負け惜しみ?\n[01:51.940]僕の夢は何だったのか\n[01:56.720]大事なことも忘れて\n[02:01.680]目の前にある守るべきもの\n[02:06.640]There's a sunshine in my mind\n[02:14.500]明日を照らすよSunshineどこまでも続く\n[02:19.000]目の前に広がるヒカリの先へ\n[02:24.670]未来のSunshine\n[02:27.200]輝くSunshine\n[02:29.900]You know it's hard,just take a chance.\n[02:31.420]信じて\n[02:33.300]明日も晴れるかな?\n[02:47.200]Rain's got me now\n[03:05.650]I guess I'm waiting for that Sunshine\n[03:09.200]Why's It only shine in my mind\n[03:15.960]I guess I'm waiting for that Sunshine\n[03:19.110]Why's It only shine in my mind\n[03:25.970]明日を照らすよSunshineどこまでも続く\n[03:30.690]目の前に広がるヒカリの先へ\n[03:36.400]未来のSunshine\n[03:38.840]輝くSunshine\n[03:41.520]You know it's hard,just take a chance.\n[03:43.200]信じて\n[03:44.829]明日も晴れるかな?\n";

  //音译/翻译歌词
  var remarkSongLyc =
      "[00:00.680]照亮明天的阳光\n[00:03.570]从窗外洒进来…敞开门扉\n[00:20.920]停下!因为你让我感觉到\n[00:22.360]自己有点过快\n[00:23.520]走吧!也许脱离了节奏\n[00:25.100]但我绝不放开你\n[00:26.280]知道吗!我希望你能亲自看看\n[00:28.560]不是这样不是这样快停下听好!糟了!\n[00:30.930]我从来没想过我会接受这一切\n[00:33.420]现在我知道我没办法降低速度\n[00:35.970]你知道这是不断地和不时地\n[00:38.210]于是谁也无法逃脱\n[00:40.300]我的梦想究竟落在何方?\n[00:45.100]为何形影不见\n[00:50.200]奋力追赶着应当守护的事物\n[00:54.860]阳光至始至终都在我心底里\n[01:02.400]照亮明天的阳光无限延伸\n[01:07.340]向着展现眼前的光明前路\n[01:12.870]Sunshine未来的阳光\n[01:15.420]Sunshine耀眼的阳光\n[01:18.100]你知道难以达成只是想去尝试一番\n[01:19.670]相信吧\n[01:21.289]明天也会放晴吗?\n[01:32.960]常因些微不足道的事情踌躇不前\n[01:37.830]总是很在意某人说过的话\n[01:42.850]如此脆弱的我亦坚信「早日必定成功!」\n[01:47.800]这是逞强还是不服输?\n[01:51.940]我的梦想实为何物\n[01:56.720]竟忘了如此重要的事\n[02:01.680]应当守护的事物就在眼前\n[02:06.640]阳光至始至终都在我心底里\n[02:14.500]照亮明天的阳光无限延伸\n[02:19.000]向着展现眼前的光明前路\n[02:24.670]未来的阳光\n[02:27.200]耀眼的阳光\n[02:29.900]你知道难以达成只是想去尝试一番\n[02:31.420]相信吧\n[02:33.300]明天也会放晴吗?\n[02:47.200]此刻雨水纷飞\n[03:05.650]我推测我所等待的就是这缕阳光\n[03:09.200]为什么它只在我心中闪烁\n[03:15.960]我推测我所等待的就是这缕阳光\n[03:19.110]为什么它只在我心中闪烁\n[03:25.970]照亮明天的阳光无限延伸\n[03:30.690]向着展现眼前的光明前路\n[03:36.400]未来的阳光\n[03:38.840]耀眼的阳光\n[03:41.520]你知道难以达成只是想去尝试一番\n[03:43.200]相信吧\n[03:44.829]明天也会放晴吗?";

  //是否显示选择器
  bool showSelect = false;
  Duration start = new Duration(seconds: 0);

  //歌词控制器
  LyricController controller;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  void initState() {
    controller = LyricController(vsync: this);
    //监听控制器
    controller.addListener(() {
      //如果拖动歌词则显示选择器
      if (showSelect != controller.isDragging) {
        setState(() {
          showSelect = controller.isDragging;
        });
      }
    });
    super.initState();
  }

  Timer _timer;
  var count = 0;

  @override
  Widget build(BuildContext context) {
    var lyrics = LyricUtil.formatLyric(songLyc);
    var remarkLyrics = LyricUtil.formatLyric(remarkSongLyc);
    return Scaffold(
      appBar: AppBar(
        title: Text("issue#8"),
      ),
      body: Column(
        children: [
          Row(
            children: [
              TextButton(onPressed: () {}, child: Text("唱片")),
              TextButton(onPressed: () {}, child: Text("歌词")),
              TextButton(onPressed: () {
                showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  builder: (BuildContext context) {
                    return LyricWidget(
                      size: const Size(double.maxFinite, double.maxFinite),
                      lyricGap: 10,
                      lyrics: lyrics,
                      lyricStyle: const TextStyle(color: Colors.white, fontSize: 14),
                      currLyricStyle: const TextStyle(color: Colors.red, fontSize: 15),
                      draggingLyricStyle: const TextStyle(color: Colors.blueGrey, fontSize: 14),
                      controller: controller,
                    );
                  },
                );
              }, child: Text("显示弹窗")),
            ],
          ),
          Expanded(
              child: PageView(
            controller: pageController,
            children: [
              TextButton(
                onPressed: () {
                  _timer?.cancel();
                  count = 0;
                  _timer = Timer.periodic(Duration(seconds: 1), (timer) {
                    count += 5;
                    controller.progress = Duration(seconds: count);
                  });
                },
                child: Text('开始播放'),
              ),
              Container(
                color: Colors.black,
                child: LyricWidget(
                  size: const Size(double.maxFinite, double.maxFinite),
                  lyricGap: 10,
                  lyricMaxWidth: 300,
                  lyrics: lyrics,
                  lyricStyle:
                      const TextStyle(color: Colors.white, fontSize: 14),
                  currLyricStyle:
                      const TextStyle(color: Colors.red, fontSize: 15),
                  draggingLyricStyle:
                      const TextStyle(color: Colors.blueGrey, fontSize: 14),
                  controller: controller,
                ),
              )
            ],
          ))
        ],
      ),
    );
  }
}
