# 4.0 API

只从 `package:flutter_lyric/flutter_lyric.dart` 导入公开 API。`src/` 下的渲染器、排版缓存和视图会话属于内部实现。

## 参数划分

| 所属 | 内容 | 生命周期 |
| --- | --- | --- |
| `LyricController` | 歌词文档、播放位置、校准偏移、播放器 source | 应用创建并 dispose，可连接多个视图 |
| `LyricView` | controller、viewId、业务事件、preset 入口 | 每个视图独立滚动、选择、吸附、恢复 |
| `LyricPreset` | 模式、文字、布局、高亮、动画、交互规则、展示 builder | 不可变，可复用、整体替换、copyWith 微调 |
| `LyricPresetScope` | 子树默认预设 | 完整值继承，不逐字段隐式合并 |

## LyricView

```dart
const LyricView({
  Key? key,
  required LyricController controller,
  LyricPreset? preset,
  Object? viewId,
  ValueChanged<LyricLineDetails>? onLineTap,
  ValueChanged<LyricLineDetails?>? onSelectionChanged,
  ValueChanged<bool>? onFollowChanged,
});
```

- 使用 `SizedBox` / `Expanded` 提供有界宽高；View 本身不接收 width / height。
- 预设优先级：显式 preset → 最近的 Scope → `LyricPresets.centered`。
- 自动 viewId 在 State 生命周期内稳定；显式 ID 在同一个 Controller 内必须唯一，重复抛出 `StateError`。
- `onSelectionChanged(null)` 表示清空选择；同一行的滚动、动画、几何更新不会重复触发此回调。
- `onFollowChanged` 仅在跟随状态改变时通知，不发送初始状态。
- 点击只有在 `interactive` 为 true 且绑定 `onLineTap` 时才派发。回调中连接播放器 seek；`resumeOnTap` 决定派发后该视图是否恢复跟随。
- 切换预设保留播放位置。切换为 activeLine 或关闭 interactive 时清空选择并恢复跟随。
- 替换 Controller 或 viewId 时重新建立独立视图会话。`clear` / `loadDocument` 清空各视图选择并恢复跟随。

## LyricPreset

构造器全部可选；所有参数都有同名 `copyWith` 参数。

| 参数 | 类型 | 默认值 / 语义 |
| --- | --- | --- |
| displayMode | LyricDisplayMode | scrollable；activeLine 仅显示当前歌词条目，可换行并包含翻译 |
| textStyle | TextStyle | fontSize: 14，合并 DefaultTextStyle |
| activeTextStyle | TextStyle | fontSize: 18，合并已解析 textStyle |
| translationTextStyle | TextStyle | fontSize: 12，合并已解析 textStyle |
| activeTranslationTextStyle | TextStyle | 空样式，合并已解析 translationTextStyle；允许完整字体微调 |
| selectedTextColor | Color? | null，回退到当前行颜色 |
| selectedTranslationTextColor | Color? | null，回退到当前翻译颜色 |
| textAlign | TextAlign | center，控制段落内换行的对齐 |
| contentAlignment | LyricContentAlignment | center；start / end 按 Directionality 解析 |
| padding | EdgeInsetsGeometry | horizontal: 20；首尾锚点空间自动计算 |
| lineSpacing | double | 20 |
| translationSpacing | double | 5 |
| activeAnchor | LyricAnchor | fraction(.5)，lineCenter |
| selectionAnchor | LyricAnchor | fraction(.5)，lineCenter |
| highlight | LyricHighlight | none |
| edgeFade | LyricEdgeFade | pixels(top: 32, bottom: 32) |
| scrollAnimation | LyricScrollAnimation | fixed(240ms, easeOutCubic) |
| lineTransition | LyricLineTransition | 进入 / 退出各 200ms，easeIn / easeOut |
| interactive | bool | true；关闭用户拖动和行点击 |
| selectionSnapMode | LyricSelectionSnapMode | afterScroll；也可 none / onDragPause |
| selectionSnapDelay | Duration | 320ms |
| resumeDelay | Duration? | 3s；null 永不自动恢复 |
| resumeOnTap | bool | true |
| emptyBuilder | WidgetBuilder? | null；无文档、空列表、activeLine 尚未开始时显示 |
| selectionBackgroundBuilder | LyricSelectionBuilder? | null；在歌词后方，IgnorePointer |
| selectionForegroundBuilder | LyricSelectionBuilder? | null；在歌词前方，可交互 |

`copyWith` 中 null 表示保留；以下参数通过显式 clear 标记清除：

```dart
preset.copyWith(
  clearSelectedTextColor: true,
  clearSelectedTranslationTextColor: true,
  clearResumeDelay: true,
  clearEmptyBuilder: true,
  clearSelectionBackgroundBuilder: true,
  clearSelectionForegroundBuilder: true,
);
```

同一个属性同时传值与 clear 标记会抛 `ArgumentError`。预设按值比较；builder / 自定义动画回调按函数相等性比较。时间与距离不能为负；fraction 范围为 0…1。构造器的数值断言与使用时的时长校验会拒绝无效参数。

吸附和恢复计时独立：afterScroll 等滚动停止后开始吸附倒计时；onDragPause 也允许拖动停顿时吸附；手指仍在拖动中时直接校正位置，以保留当前手势，松手后的吸附使用 scrollAnimation。resumeDelay 从本次浏览停止后计时。若恢复先发生，会取消尚未执行的吸附。新的手动交互重新开始计时。

内置预设是完整值：`centered` 居中、`leading` 起始侧对齐并带渐变、`singleLine` 仅当前条目且默认不可交互。它们包含自己的颜色；想跟随应用文字主题可以从 `const LyricPreset()` 开始。

## 小型值对象

```dart
const LyricAnchor.fraction(double position,
    {LyricAnchorTarget target = LyricAnchorTarget.lineCenter});
const LyricAnchor.pixels(double position,
    {LyricAnchorTarget target = LyricAnchorTarget.lineCenter});
// target: mainText / translationText / lineCenter，均对齐对应区域中心。
// 没有翻译时 translationText 回退到主文本中心。

const LyricHighlight.none();
const LyricHighlight.solid(Color color, {double tailFadeWidth = 0});
const LyricHighlight.gradient(LinearGradient gradient, {double tailFadeWidth = 0});

const LyricEdgeFade.none();
const LyricEdgeFade.pixels({double top = 0, double bottom = 0});
const LyricEdgeFade.fraction({double top = 0, double bottom = 0});
// 上下渐隐范围重叠时按比例缩小；none 不创建遮罩层。

const LyricScrollAnimation.none();
const LyricScrollAnimation.fixed({
  Duration duration = const Duration(milliseconds: 240),
  Curve curve = Curves.easeOutCubic,
});
LyricScrollAnimation.byDistance({
  required Map<double, Duration> durations,
  Duration duration = const Duration(milliseconds: 240),
  Curve curve = Curves.easeOutCubic,
});
const LyricScrollAnimation.custom(LyricScrollAnimationResolver resolver);
// resolver 接收绝对像素距离，返回 LyricAnimation(duration: ..., curve: ...)。
// byDistance 防御性复制并排序，使用不大于距离的最大阈值；无匹配时用 duration。

const LyricLineTransition.none();
const LyricLineTransition({
  Duration enterDuration = const Duration(milliseconds: 200),
  Duration exitDuration = const Duration(milliseconds: 200),
  Curve enterCurve = Curves.easeIn,
  Curve exitCurve = Curves.easeOut,
});
```

## Builder 上下文

```dart
typedef LyricSelectionBuilder = Widget Function(
  BuildContext context, LyricSelectionDetails details);
```

`LyricLineDetails` 的只读字段：`viewId`、`index`、`line`、`seekPosition`。

`LyricSelectionDetails` 的只读字段：

| 字段 | 含义 |
| --- | --- |
| line | LyricLineDetails |
| viewportSize | 整个歌词视口尺寸 |
| lineRect | 所选条目的区域：全视口宽度，包含主文本和翻译的高度，不含行距 |
| contentRect | 从 lineRect 扣除水平 padding 后的内容区域 |
| anchorY | selectionAnchor 在视口内的 y 坐标 |
| isActive | 所选条目是否也是当前播放条目 |
| isDragging | 是否在拖动 |
| isSnapped | 对齐误差小于 0.5 逻辑像素 |
| onTap | VoidCallback?；未绑定业务行点击或禁用交互时为 null |
| resumeFollow | VoidCallback；只恢复本视图 |

builder 只在手动浏览且存在选中行时构建，必要时随着几何变化更新。使用 `Stack` / `Positioned` 等布置内容。背景不参与命中测试。旧 action 在歌词或视图被替换、选择被清除后不执行。

## LyricController

```dart
LyricController({
  LyricDocument? document,
  LyricProgressSource? progressSource,
  Duration initialPosition = Duration.zero,
  Duration timeOffset = Duration.zero,
});
```

Controller 实现只读 `ValueListenable<LyricPlaybackState>`：`value`、`addListener`、`removeListener`。`activeLineIndexListenable` 仅在索引改变时通知。没有第二个公开 Controller，也没有可写的内部 ValueNotifier。

| API | 行为 |
| --- | --- |
| load(String lyric, {String? translation, LyricParser? parser}) | 自动检测或用指定解析器载入 |
| loadDocument(LyricDocument document) | 替换不可变文档，保留播放位置和 timeOffset |
| clear() | 清空文档，保留播放位置和 timeOffset |
| setPosition(Duration position) | 手动驱动；已绑定 source 时抛 StateError |
| progressSource getter/setter | 替换时取消旧订阅；null 解绑；不 dispose source 或 player |
| timeOffset getter/setter | 用户校准偏移，Duration |
| document / position / effectivePosition | 只读播放状态 |
| activeLineIndex / activeLine | nullable；空文档或尚未到首行时为 null |
| isAdvancing | source 提供的状态；手动模式为 false |
| resumeFollow({Object? viewId, bool animate = true}) → Future<void> | 恢复目标视图跟随 |
| scrollToLine(int index, {Object? viewId, bool animate = true}) → Future<void> | 主动浏览指定条目；遵循目标预设恢复规则；activeLine 模式忽略 |
| hasClients / attachedViewIds | 只读连接信息；ID 列表不可修改 |
| dispose() | 取消订阅、停止采样，之后写入抛 StateError |

有目标视图时，越界 index 抛 `RangeError`；显式未知 viewId 抛 `StateError`。不传 viewId 广播到全部视图，无视图时 no-op。异步滚动在结束或被中断时完成。应用主动 scrollToLine 可以浏览不可交互视图；interactive 控制用户输入。

播放快照包含 document、position、timeOffset、effectivePosition、activeLineIndex、isAdvancing，作为一次更新原子发布。重复时间戳选择最后一条；超过最后一条仍保持该条目。

```
effectivePosition = player position + document.offset + controller.timeOffset
seekPosition = max(Duration.zero, line.start - document.offset - controller.timeOffset)
```

Controller 只保留一条 source 订阅和一个帧采样器。所有视图都关闭 TickerMode、卸载或应用进入后台时停止帧采样；source 的事件更新仍然有效。不根据本地时间外推播放器进度。

## 文档与解析

`LyricDocument(lines: ..., tags: ..., offset: ...)` 防御性复制集合并按开始时间稳定排序。省略 offset 时从 LRC `[offset:毫秒]` 标签读取；显式 offset 优先。`copyWith` 使用具名参数。`LyricLine` 的 words 也不可修改。

`LyricDocument.parse(text, translation: ..., parser: ...)` 自动检测 LRC / YRC / QRC / fallback。自定义解析器继承 `LyricParser`，实现 `canParse` 和 `parse(String mainLyric, {String? translationLyric})`。逐字时间相对整首歌词，而非相对所在行。`LrcToQrcUtil` 继续用于格式转换。
