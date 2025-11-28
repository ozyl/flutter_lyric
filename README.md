# flutter_lyric

[![pub package](https://img.shields.io/pub/v/flutter_lyric.svg)](https://pub.dev/packages/flutter_lyric)
[![likes](https://img.shields.io/pub/likes/flutter_lyric)](https://pub.dev/packages/flutter_lyric/score)
[![license](https://img.shields.io/github/license/ozyl/flutter_lyric)](LICENSE)
[![demo](https://img.shields.io/badge/demo-online-brightgreen)](https://ozyl.github.io/flutter_lyric/)


**中文简介**  
`flutter_lyric` 是一个专注于歌词体验的 Flutter 组件库，提供平滑滚动、高亮动画、翻译/逐字歌词渲染、触摸选择、遮罩等能力，帮助音乐类应用快速实现专业歌词视图。
> 本 README 面向 3.0.0 全新版本，介绍重写后的渲染链路、可组合 mixin 以及统一 `LyricController` API。  

**English Overview**  
`flutter_lyric` is a Flutter toolkit for immersive lyric presentation. It ships smooth scrolling, dynamic highlighting, translation/word-by-word rendering, touch selection, masking, and extensive styling hooks so you can build player-grade lyric experiences in minutes.


> This README targets the brand-new 3.0.0 release and explains the rewritten rendering pipeline, composable mixins, and the unified `LyricController` API.

## ✨ 核心特性 · Highlights

**中文**
- 🔥 渐变/颜色高亮：根据播放进度实时推进高亮宽度，可叠加渐变与尾部淡出
- 🌍 主/副歌词：同屏展示翻译或音译文本，行距与样式完全可调
- 🌀 平滑滚动：多段滚动时长映射、惯性与自定义锚点，避免跳动
- 🎯 触摸交互：拖拽选择、点击行、自动恢复、高亮锚点指示
- 🎨 高度可定制：`LyricStyle` 暴露 30+ 参数，可快速打造品牌化主题
- 📦 内置解析：默认支持 `.lrc` 与 `.qrc`，可注入自定义解析器
- 🧱 Mixins 设计：滚动、遮罩、行切换、高亮逻辑模块化，方便二次开发

**English**
- 🔥 Gradient or solid highlights tied to playback progress with optional trailing fade
- 🌍 Primary + secondary lyrics for translations or romanization with independent spacing/styles
- 🌀 Smooth scrolling with distance-based duration mapping, inertia, and configurable anchors
- 🎯 Touch interactions for scrubbing, tapping, auto-resume, and anchor indicators
- 🎨 Deep customization via 30+ `LyricStyle` parameters to match any visual identity
- 📦 Built-in parsers for `.lrc` and `.qrc`, plus hooks for custom formats
- 🧱 Mixin-based architecture so scroll, mask, switch, and highlight logic can be recomposed

## 🚀 安装 · Installation

**中文**
1. 在项目的 `pubspec.yaml` 中加入 `flutter_lyric: ^3.0.0`
2. 执行 `flutter pub get` 拉取依赖

**English**
1. Add `flutter_lyric: ^3.0.0` to your project's `pubspec.yaml`
2. Run `flutter pub get` to install the package

## 🎬 在线演示 · Live Demo

**中文**  
👉 [在线体验](https://ozyl.github.io/flutter_lyric/) - 查看完整功能演示

**English**  
👉 [Live Demo](https://ozyl.github.io/flutter_lyric/) - See it in action

## 🏁 快速开始 · Quick Start

**中文**  
实例化 `LyricController`，调用 `loadLyric`（可选传入翻译文本），再将 `LyricView` 嵌入到 widget 树即可。

**English**  
Create a `LyricController`, call `loadLyric` (optionally with translated lyrics), and place `LyricView` in your widget tree.

```dart
final controller = LyricController()
  ..loadLyric(
    mainLyricString,
    translationLyric: translationString,
  );

@override
void dispose() {
  controller.dispose();
  super.dispose();
}

@override
Widget build(BuildContext context) {
  return LyricView(
    controller: controller,
    width: double.infinity,
    height: 320,
  );
}
```

**中文**  
将播放器的进度流持续推送到 `controller.setProgress`，即可驱动高亮与滚动。

**English**  
Feed your player position into `controller.setProgress` to drive highlighting and scrolling.

```dart
audioPlayer.positionStream.listen(controller.setProgress);
```

## 🎚️ 控制与样式 · Controller & Style

**中文**
- `LyricController.loadLyric` / `loadLyricModel`：加载文本或自定义模型
- `setStyle`：传入 `LyricStyle` 或 `LyricStyles` 预设，控制字体、行距、渐隐、滚动曲线等
- `lyricOffset`：以毫秒为单位整体校准歌词时间
- `styleNotifier`、`activeIndexNotifier` 等 ValueNotifier 可与外部 UI 联动

**English**
- `LyricController.loadLyric` / `loadLyricModel`: load plain text or custom lyric models
- `setStyle`: apply a `LyricStyle` or presets from `LyricStyles` to tweak typography, spacing, fade range, and scroll curves
- `lyricOffset`: shift the entire script forward/backward in milliseconds for sync
- Exposed `ValueNotifier`s (`styleNotifier`, `activeIndexNotifier`, …) let you coordinate external UI

## 🎨 LyricStyle 参数 · LyricStyle Options

| 字段 / Field | 中文说明 | English Description |
| --- | --- | --- |
| `textStyle` / `activeStyle` / `translationStyle` | 控制普通行、播放行、翻译行的字体、字号与颜色 | Typography for idle, active, and translation lines |
| `lineTextAlign` / `contentAlignment` | 行文本对齐方式与整体交叉轴对齐策略 | Horizontal alignment per line plus cross-axis alignment |
| `lineGap` / `translationLineGap` | 主歌词与翻译歌词的行间距 | Spacing between lyric lines and between translation blocks |
| `contentPadding` | 歌词区域的统一内边距 | Insets around the rendered lyric area |
| `selectionAnchorPosition` / `activeAnchorPosition` | 选中/播放锚点在视图中的垂直相对位置 | Vertical anchors (0~1 or px) used for selection/playing lines |
| `selectionAlignment` / `activeAlignment` | 高亮条在水平方向的排列方式 | Main-axis alignment for highlight bars and anchors |
| `fadeRange` | 顶部/底部渐隐范围，可选绝对像素或百分比 | Top/bottom fade distances (absolute or relative) |
| `scrollDuration` / `scrollDurations` / `scrollCurve` | 全局滚动时长、距离映射表与补间曲线 | Base scroll duration, distance-to-duration map, and easing curve |
| `selectionAutoResumeDuration` / `activeAutoResumeDuration` / `selectionAutoResumeMode` | 控制拖拽后多久恢复自动滚动以及恢复策略 | Auto-resume delays and behavior after manual scrubbing |
| `activeHighlightColor` / `activeHighlightGradient` / `activeHighlightExtraFadeWidth` | 播放行高亮的纯色、渐变与尾部淡出宽度 | Colors/gradients for progress highlights plus trailing fade |
| `selectedColor` / `selectedTranslationColor` | 手动选中行的文字/翻译颜色 | Text colors applied when a user selects a line |
| `enableSwitchAnimation` + `switchEnterDuration` / `switchExitDuration` / `switchEnterCurve` / `switchExitCurve` | 控制行切换动画开关、时长与曲线 | Toggle and tune line switch animations |
| `activeLineOnly` / `disableTouchEvent` | 仅绘制当前播放行或禁止触摸事件 | Render-only-active-line mode and input disabling |

> 更完整的字段列表与默认值可在 `lib/core/lyric_style.dart` 中查阅，并可通过 `LyricStyles` 预设作为起点进行 `copyWith`。

## 🪄 常用交互 · Interactions

**中文**  
通过事件或回调响应用户手势，例如点击歌词定位或监听拖拽状态。

```dart
controller.setOnTapLineCallback((Duration position) {
  audioPlayer.seek(position);
});

controller.registerEvent(LyricEvent.stopSelection, (_) {
  // 用户开始拖拽，可展示“回到当前行”按钮
});

controller.registerEvent(LyricEvent.resumeActiveLine, (_) {
  // 恢复自动跟随时隐藏提示
});
```

**English**  
Use the built-in callbacks/events to react to gestures, e.g. seeking on tap or showing UI during manual scrubbing.

## 📄 翻译歌词解析 · Translation Parsing

**中文**  
`loadLyric` 支持额外的翻译文本，库会按时间戳自动匹配；若你有自定义协议，可实现 `LyricParse` 并调用 `parseRaw` 或直接注入 `LyricModel`。

**English**  
`loadLyric` accepts an optional translation string that is aligned by timestamp. For custom formats, implement `LyricParse` or build your own `LyricModel`.

```dart
final customModel = CustomParser().parseRaw(rawLyric);
controller.loadLyricModel(customModel);
```

## 🔁 从 2.x 升级到 3.0.0 · Upgrade Guide

**中文**
- `LyricWidget` 已统一为 `LyricView`，所有状态由 `LyricController` 提供
- 旧的 `changeUI`/`LyricUI` 扩展点合并进 `LyricStyle`
- 触摸/滚动回调改由 `LyricEvent` 与 `setOnTapLineCallback` 统一管理
- 逐字高亮、翻译行与遮罩开箱即用，无需再自定义 painter

**English**

- `LyricWidget` is merged into `LyricView`, and `LyricController` becomes the single source of truth
- Previous `changeUI`/`LyricUI` hooks are replaced by the more capable `LyricStyle`
- Touch/scroll callbacks now flow through `LyricEvent` and `setOnTapLineCallback`
- Word-level highlight, translation rows, and masks are built in—custom painters are rarely needed

## 🧪 示例与调试 · Examples & Debugging

-  `example/lib/main.dart` 

## 🤝 贡献 · Contributing

**中文**  
欢迎通过 Issue / PR 分享新功能、修复或示例。提交前请运行 `flutter test` 并附上动图/截图说明效果。

**English**  
Contributions via issues or pull requests are welcome. Please run `flutter test` before submitting and include screenshots or gifs when possible.

## 📄 许可证 · License

**中文**  
项目基于 [MIT License](LICENSE) 发布，可自由商用，欢迎在产品中标注 “Powered by flutter_lyric”。

**English**  
Released under the [MIT License](LICENSE). Commercial use is allowed—giving credit such as “Powered by flutter_lyric” is appreciated.
