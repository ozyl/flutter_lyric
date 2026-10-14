# flutter_lyric

[![pub package](https://img.shields.io/pub/v/flutter_lyric.svg)](https://pub.dev/packages/flutter_lyric)
[![license](https://img.shields.io/github/license/ozyl/flutter_lyric)](LICENSE)
[![Live Demo](https://img.shields.io/badge/demo-online-brightgreen)](https://ozyl.github.io/flutter_lyric/)

Flutter 歌词组件，支持 LRC / QRC / YRC、翻译、逐字高亮和滚动选择。一个 `LyricController` 可以连接多个视图；每个视图独立管理滚动和选择。

A Canvas-based lyric widget with translations, word-timed highlighting and native Flutter scrolling. One controller shares playback across views; each view keeps its own browsing state.

**4.1.0** adds Apple Music-style motion, configurable countdown dots and reusable line transitions to the 4.0 API. Minimum library versions remain **Dart 2.12 / Flutter 2.0**. The audio-player example requires **Dart 3.8.1 or later**. Upgrading from 3.x requires the [migration guide](doc/migration.md).

- [在线演示 / Live Demo](https://ozyl.github.io/flutter_lyric/)
- [完整 API 与参数划分 / API reference](doc/api.md)
- [4.0 → 4.1 / 3.x → 4.x 迁移 / Migration](doc/migration.md)
- [示例源码 / Example source](example/lib/main.dart)
- [渲染性能与验证 / Rendering performance](doc/apple_music_performance.md)

## Installation

```yaml
dependencies:
  flutter_lyric: ^4.1.0
```

Run `flutter pub get`, then import `package:flutter_lyric/flutter_lyric.dart`.

## What's new in 4.1

- Apple Music, Cascade, Pulse and Drift join Moss, Aurora and Cinema as reusable presets. Word lift, character float, row motion and distance blur can be configured independently.
- Canvas countdown dots mark intros and interludes, with optional `vocalStart` metadata for intro credits. Dots are enabled by default; use `countdown: const LyricCountdown.none()` to disable them.
- Named, composed and custom line transitions share one renderer and preserve interrupted animation state. Solid-color floating text uses bounded glyph atlases to reduce long-line switch compositing.
- Lyric Studio opens with Apple Music first, with 11 styles, 17 transition choices, shared timing previews, undo/redo and Dart configuration export.

Existing 4.0 integrations keep their API. Built-in motion has been refreshed; see the [4.1 upgrade notes](doc/migration.md#upgrading-from-40-to-41) for restoring the earlier transitions.

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

## 前奏与间奏倒计时

所有内置预设默认启用小圆点，并按风格适配颜色、尺寸、对齐和间距。计时统一为三个配置：

```dart
final preset = LyricPresets.appleMusic.copyWith(
  countdown: LyricPresets.appleMusic.countdown.copyWith(
    dotCount: 3,
    dotDuration: const Duration(seconds: 3), // 整组圆点消退总时长
    breathDuration: const Duration(seconds: 1), // 有多余时间时，先呼吸等待
  ),
);
```

各点均分 `dotDuration`，最后一个点在下一句开始时完成消退。空白不足这个时长时不显示圆点；刚好够时直接消退；多出来的时间最多用于 `breathDuration` 的呼吸等待。改变圆点数量不改变总时长。可使用 `const LyricCountdown.none()` 关闭。

圆点显示期间独占播放焦点，上一句回到非焦点样式。圆点直接由歌词视口通过 Canvas 绘制；隐藏时不占位，出现和结束时沿用歌词滚动与排版过渡。手动浏览时随歌词滚动，滚回后按当前播放进度显示。呼吸、暂停、seek 和偏移均沿用 Controller 的播放时间；减少动画或关闭 `TickerMode` 时停止呼吸动画。

间奏依据 `LyricLine.end`、完整的逐字结束时间或 LRC 空白时间戳判断。普通 LRC 只有开始时间时不会猜测句子唱多久；例如 `[00:12]\n[00:22]下一句` 标记了 10 秒空白。

如果歌词来源提供正文起点（如 QQ 音乐响应中的 `startTs`），可传入 `vocalStart`。即使最后一条署名结束后没有足够空白，也能借用 0 到开唱点之间的署名歌词时间：

```dart
final document = LyricDocument.parse(
  qrcText,
  translation: translationText,
  vocalStart: const Duration(milliseconds: 11438), // STAY 的 startTs
);
controller.loadDocument(document);
// 配合上面的配置，在 00:07.438～00:11.438 显示圆点。
```

`vocalStart` 与歌词时间戳使用同一时间轴，沿用文档和 Controller 的偏移。前奏从 0 到首句正文开始，STAY 为 11.438 秒；署名的开始和结束时间不会缩短它。如果整个前奏仍不足 `dotDuration`，圆点不显示，也不会从负时间开始或压缩消退过程。署名文本与逐字时间保留，显示窗口之前正常跟随署名。

下载时可将 `startTs` 保存为同名 `.meta.json`（如 `{"startTs": 11438}`），加载时读取并转换为 `Duration`。example 的《STAY》通过 `loadBundledLyrics` 自动读取这个文件；见 [歌曲加载器](example/lib/demo_songs.dart)。

查看 [完整倒计时 API](doc/api.md#lyriccountdown)。Studio 的「动效 → 前奏与间奏小圆点」提供数量、时长、呼吸时长三项调节，支持撤销、重做和导出。

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
| `LyricPresets.moss` / 苔原 | Leading text, gentle upward entrance, soft green highlight | `Color(0xFF101F1C)` |
| `LyricPresets.aurora` / 极光 | Centered text, opposing arc transitions, mint-to-lilac gradient | `Color(0xFF17172E)` |
| `LyricPresets.cinema` / 银幕 | Single entry, soft-focus crossfade | `Color(0xFF171B1C)` |
| `LyricPresets.appleMusic` / Apple Music | Fixed wrapping, staggered motion, distance blur, word lift/float | `Color(0xFF251E29)` |
| `LyricPresets.cascade` / 瀑布 | Staggered rows settling in three steps, no word motion | `Color(0xFF17272F)` |
| `LyricPresets.pulse` / 跃动 | Spring overshoot, settling bounce and brisk word lift | `Color(0xFF2C2029)` |
| `LyricPresets.drift` / 浮游 | Slow diagonal line drift and character float | `Color(0xFF222738)` |

All seven are `const LyricPreset` values and remain adjustable with `copyWith`. They use light text for dark surfaces; backgrounds and audio controls belong to your app. Aurora is the default. The old `leading`, `centered` and `singleLine` names have been removed; see the [migration guide](doc/migration.md).

切句动画也有独立预设，可在任何风格上组合：

```dart
final preset = LyricPresets.moss.copyWith(
  lineTransition: LyricLineTransitions.spring.copyWith(
    enterDuration: const Duration(milliseconds: 800),
  ),
);
```

`LyricLineTransitions` includes `rise`, `paper`, `spring`, `orbit`, `pendulum`,
`zoom`, `step`, `drift` and `focus`, alongside basic fade/scale/slide/blur effects.
Use `cinematic` for a full single-line dissolve; `focus` keeps neighboring list
rows readable. Studio offers 17 named choices with motion descriptions. The
complete styles pair these with their own scrolling and word effects.

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

## Apple Music-inspired view

统一的 `LyricView` 现在支持 `LyricPresets.appleMusic`。列表滚动、行间运动、行状态过渡和逐字效果可以独立配置；Moss、Aurora、Cinema 保留双样式排版，Apple Music、Cascade、Pulse、Drift 使用固定折行。Studio 统一在预设列表中切换，动效参数、原版对照和普通 LRC 预览共用同一个舞台。

```dart
LyricView(controller: controller, preset: LyricPresets.appleMusic);

// 在任意预设上组合滑入与淡出。
final preset = LyricPresets.moss.copyWith(
  lineTransition: const LyricLineTransition.effects([
    LyricLineEffect.slide(Offset(24, 8)),
    LyricLineEffect.fade(.35),
  ]),
);
```

`LyricLineTransition.custom` 接收进度、起始/目标状态和行几何，返回这一帧的视觉状态。详见 [过渡与组合规则](doc/api.md#播放切句与效果组合)。Studio 动效面板可以独立切换内置、组合和自定义示例。

也可使用便捷包装 `AppleMusicLyricView` 和 `AppleMusicLyricStyle`，通过 `style.toPreset()` 复用统一实现。包装组件显式传入预设，因此不读取 `LyricPresetScope`。

```dart
AppleMusicLyricView(
  controller: controller,
  viewId: 'apple-music',
  style: const AppleMusicLyricStyle().copyWith(
    maxBlurSigma: 4,
    blurWhenBrowsing: false, // 滑动选择期间保持所有歌词清晰
    wordLift: 2.5,
    wordPopDuration: Duration(milliseconds: 900),
    characterFloatAmplitude: 1.4,
    characterFloatPeriod: Duration(milliseconds: 6000),
    characterFloatStagger: Duration(milliseconds: 180),
    inactiveScale: .92,
  ),
  onLineTap: (line) {
    // Connect to your player: player.seek(line.seekPosition).
    // For a controller without a progressSource:
    controller.setPosition(line.seekPosition);
  },
)
```

Apple Music defaults to `distanceBlur.whenBrowsing: false` (`blurWhenBrowsing: false` in the compatibility style), keeping lyrics and translations crisp while dragging, scrolling or resting on a selection. Distance blur returns when playback following resumes. Set it to `true` to retain blur while browsing. The Studio demo enables **滑动选择时保持清晰** by default.

True word timestamps take priority. For plain LRC, the view can divide each line's duration evenly among Unicode grapheme clusters. The end is taken from `LyricLine.end` or the next later line timestamp. A final line without an end highlights as a whole; simulated timing is approximate and never modifies the shared document. Set `simulateWordTiming: false` to disable it.

Word Pop rises to `wordLift` over `wordPopDuration` at each timed word's onset, then holds that height until the line becomes inactive. Character Float adds a slowly traveling drift of up to ±`characterFloatAmplitude` around the Word Pop position, without changing the held height. For example, a 2.5px rise with a 1.4px float stays within 1.1–3.9px after rising and fully highlighting. Its independent controls are `characterFloatAmplitude`, `characterFloatPeriod` and `characterFloatStagger`. By default, `characterFloatMode: LyricFloatMode.highlighted` eases float in as the highlight reaches each grapheme; unhighlighted characters do not float. Set it to `LyricFloatMode.all` for the previous whole-line behavior, including when highlighting is disabled. Unified presets use `wordEffects.floatMode` for the same choice, also available in Studio. Float continues while playback is paused. Lines without word timing highlight and float as a whole; without Word Pop, float moves around the resting baseline. Set either effect's amplitude to zero to disable it separately; disabling Float leaves the Word Pop height intact. Float only repaints; it never advances playback or remeasures text. In widget tests, use bounded `pump` durations while float is enabled, or disable it before `pumpAndSettle`.

Programmatic scrolling farther than one viewport height jumps directly to the target and clears residual line lag. Shorter moves retain the configured scroll duration and stagger, including when resuming playback following.

Text wraps at its full size and scales within a fixed line slot, so transitions never rewrap the text. Backgrounds and player UI remain the host's responsibility. Studio opens with **Apple Music** selected in the preset gallery; use the shared inspector and stage timing menu to tune effects, preview plain LRC and compare with the ordinary view. See the [style and behavior reference](doc/api.md#apple-music-inspired-view).

Solid-color Character Float reuses bounded glyph atlases at the view's device pixel ratio. Partial highlight tails, custom gradients, oversized atlases and unsupported engines use the paragraph renderer. Clip paths and shaped geometry are cached; see the [mobile rendering analysis and benchmarks](doc/apple_music_performance.md) for costs and verification steps.

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

CI also runs the latest `pana --exit-code-threshold 0` with API documentation enabled, requiring all available pub points. Before publishing, follow the [release checks](doc/releasing.md).
