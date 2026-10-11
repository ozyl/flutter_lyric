# flutter_lyric

[![pub package](https://img.shields.io/pub/v/flutter_lyric.svg)](https://pub.dev/packages/flutter_lyric)
[![license](https://img.shields.io/github/license/ozyl/flutter_lyric)](LICENSE)

Flutter 歌词组件，支持 LRC / QRC / YRC、翻译、逐字高亮和滚动选择。一个 `LyricController` 可以连接多个视图；每个视图独立管理滚动和选择。

A Canvas-based lyric widget with translations, word-timed highlighting and native Flutter scrolling. One controller shares playback across views; each view keeps its own browsing state.

This branch contains the **4.0 API preview**, with breaking changes from 3.x. Minimum library versions remain **Dart 2.12 / Flutter 2.0**. The audio-player example uses a newer SDK for its player dependencies.

- [完整 API 与参数划分 / API reference](doc/api.md)
- [3.x → 4.0 迁移 / Migration](doc/migration.md)
- [示例 / Example](example/lib/main.dart)

## Quick start

```dart
import 'package:flutter/material.dart';
import 'package:flutter_lyric/flutter_lyric.dart';

class Lyrics extends StatefulWidget {
  const Lyrics({Key? key}) : super(key: key);
  @override
  State<Lyrics> createState() => _LyricsState();
}

class _LyricsState extends State<Lyrics> {
  final controller = LyricController()
    ..load('[00:00.00]First line\n[00:04.00]Second line');

  @override
  Widget build(BuildContext context) => Container(
    height: 320,
    color: const Color(0xFF17172E),
    child: LyricView(
      controller: controller,
      preset: LyricPresets.aurora,
      onLineTap: (line) {
        // Connect to your player: player.seek(line.seekPosition).
        // For this standalone manual-position example:
        controller.setPosition(line.seekPosition);
      },
    ),
  );

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }
}
```

手动接入时调用 `controller.setPosition(playerPosition)`。也可以传入 `LyricProgressSource`：Controller 在可见、启用且播放中时，每帧读取播放器当前位置；暂停时仍接收 seek 等事件，不另建播放时钟。绑定 source 后，手动 `setPosition` 会抛出 `StateError`。

For a player integration, provide `LyricProgressSource` with a current-position getter, an advancing flag, and a changes stream. The controller owns the subscription, not the player. See the [just_audio adapter](example/lib/just_audio_progress_source.dart).

## Presets and fine tuning

`LyricPreset` 包含显示模式、文字、布局、动画、交互规则和展示 builder。它是不可变的完整预设；通过 `copyWith` 微调，无需更换 Widget 类型。

A preset switches appearance, behavior and presentation builders together. Use `copyWith` to adjust individual settings:

```dart
final preset = LyricPresets.moss.copyWith(
  activeTextStyle: LyricPresets.moss.activeTextStyle.copyWith(fontSize: 26),
  activeTranslationTextStyle: const TextStyle(fontSize: 16, color: Colors.white),
  activeAnchor: const LyricAnchor.fraction(.35,
      target: LyricAnchorTarget.mainText),
  lineSpacing: 24,
  resumeDelay: const Duration(seconds: 5),
  highlight: const LyricHighlight.solid(Colors.white, tailFadeWidth: 24),
);
```

The built-in styles come directly from Lyric Studio:

| Preset | Style | Suggested background |
| --- | --- | --- |
| `LyricPresets.moss` / 苔原 | Leading text, soft green word highlight, 40% main-text anchor | `Color(0xFF101F1C)` |
| `LyricPresets.aurora` / 极光 | Centered text, mint-to-lilac gradient, 50% main-text anchor | `Color(0xFF17172E)` |
| `LyricPresets.cinema` / 银幕 | Single active entry, warm highlight, spacious subtitle | `Color(0xFF171B1C)` |

All three are `const LyricPreset` values and remain adjustable with `copyWith`. They use light text for dark surfaces; backgrounds and audio controls belong to your app. Aurora is the default. The old `leading`, `centered` and `singleLine` names have been removed; see the [migration guide](doc/migration.md).

`LyricPresetScope` supplies a whole preset to descendants. An explicit `LyricView.preset` wins; omitted fields do not merge across scopes. Text styles themselves merge with ambient `DefaultTextStyle` and the corresponding base style.

```dart
LyricPresetScope(
  preset: preset,
  child: Builder(builder: (context) => LyricView(
    controller: controller,
    preset: LyricPresetScope.of(context).copyWith(lineSpacing: 28),
  )),
)
```

Nullable `copyWith` arguments retain their current value. Use `clearResumeDelay: true`, `clearEmptyBuilder: true`, etc. to remove a value. Clearing and setting the same property together throws `ArgumentError`.

## Selection UI

选择区 builder 属于预设；业务回调属于 `LyricView`。builder 的尺寸是整个视口，坐标相对视口。背景忽略点击，前景可以通过 `details.onTap` 和 `details.resumeFollow` 放置按钮。

Builders cover the viewport and receive local geometry. The background ignores input. The foreground can provide actions; lyrics stay Canvas-rendered.

```dart
final withSelection = preset.copyWith(
  selectionForegroundBuilder: (context, details) => Stack(children: [
    Positioned(
      right: 8,
      top: details.anchorY - 24,
      child: IconButton(
        icon: const Icon(Icons.play_arrow),
        onPressed: details.onTap,
      ),
    ),
  ]),
);
```

`onLineTap` receives a player-time `seekPosition`, already adjusted for document and controller offsets. The library never seeks the player automatically. Selection callbacks fire only when the selected entry changes or clears, not on each animation frame.

## Shared controller

```dart
Row(children: [
  Expanded(child: LyricView(
    controller: controller,
    viewId: 'main',
    preset: LyricPresets.moss,
  )),
  Expanded(child: LyricView(
    controller: controller,
    viewId: 'compact',
    preset: LyricPresets.cinema,
  )),
])
```

`controller.resumeFollow(viewId: 'main')` targets one view; omitting `viewId` targets all attached views. Generated IDs are stable for the view's lifetime. Explicit IDs must be unique per controller.

## Rendering and checks

`lib/src/` contains private view sessions, a Scrollable-backed viewport, and cached text metrics. Painting does not publish selection state. Normal paragraphs establish exact scrolling geometry; active paragraphs, masks and word boxes are lazy. Active-only mode measures just the current entry. Only visible entries are painted.

```sh
flutter pub get --no-example
flutter analyze --no-pub
flutter test --no-pub
flutter test test/benchmarks/lyric_load_benchmark.dart --reporter expanded
flutter test test/benchmarks/lyric_scroll_benchmark.dart --reporter expanded
```

CI checks both Flutter 2.0.6 (Dart 2.12.3) and a modern Flutter release. Pixel tests retain independent reference calculations for alpha compositing, fractional positions, wrapped lyrics and highlight tails.
