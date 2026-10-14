// @dart=3.8

import 'package:flutter_lyric/flutter_lyric.dart';

/// Studio labels for the library's composable line animation presets.
class DemoLineTransition {
  const DemoLineTransition(this.name, this.description, this.transition,
      {this.singleLine});

  final String name;
  final String description;
  final LyricLineTransition transition;
  final LyricLineTransition? singleLine;

  LyricLineTransition forMode(LyricDisplayMode mode) =>
      mode == LyricDisplayMode.activeLine
          ? (singleLine ?? transition)
          : transition;
}

const demoLineTransitions = [
  DemoLineTransition('关闭切句', '立即切换，适合极简阅读。', LyricLineTransitions.none),
  DemoLineTransition('经典切句', '沿用正文与当前句的字号过渡。', LyricLineTransitions.classic),
  DemoLineTransition('淡入淡出', '只改变明暗，保留周围歌词。', LyricLineTransitions.fade),
  DemoLineTransition('缩放切句', '当前句从小到大，突出重音。', LyricLineTransitions.scale),
  DemoLineTransition('滑入切句', '沿右下方向进入落点。', LyricLineTransitions.slide),
  DemoLineTransition('模糊切句', '从柔焦变清晰，不改变位置。', LyricLineTransitions.blur),
  DemoLineTransition('滑入＋淡出', '轻移与明暗同步变化。', LyricLineTransitions.slideFade),
  DemoLineTransition('Apple 切句', '紧凑缩放与淡出，适合错位滚动。', LyricLineTransitions.appleMusic),
  DemoLineTransition('轻盈浮升', '从下方轻轻升起，缓慢放大到位。', LyricLineTransitions.rise),
  DemoLineTransition('纸页滑入', '先横向滑动，文字随后显现。', LyricLineTransitions.paper),
  DemoLineTransition('弹簧回落', '放大越过落点，再轻弹一次收稳。', LyricLineTransitions.spring),
  DemoLineTransition('弧光掠入', '新旧句沿相反弧线交接，带纵向起伏。', LyricLineTransitions.orbit),
  DemoLineTransition('钟摆回落', '左右摆动逐次减弱，相邻句反向摆动。', LyricLineTransitions.pendulum),
  DemoLineTransition('镜头推进', '从略大的虚焦文字，收进清晰平面。', LyricLineTransitions.zoom),
  DemoLineTransition('分段跃迁', '沿水平方向轻移，分三段抵达落点。', LyricLineTransitions.step),
  DemoLineTransition('余韵漂移', '沿斜向缓慢漂入，退场时反向飘散。', LyricLineTransitions.drift),
  DemoLineTransition('雾化交叠', '先对焦再显现；单行模式完整交叉淡出。', LyricLineTransitions.focus,
      singleLine: LyricLineTransitions.cinematic),
];
