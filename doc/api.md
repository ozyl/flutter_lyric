# 4.1 API

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
- 预设优先级：显式 preset → 最近的 Scope → `LyricPresets.aurora`。
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
| countdown | LyricCountdown | 默认启用前奏 / 间奏小圆点 |
| scrollAnimation | LyricScrollAnimation | fixed(240ms, easeOutCubic) |
| lineTransition | LyricLineTransition | 进入 / 退出各 200ms，easeIn / easeOut |
| layoutMode | LyricLayoutMode | dualStyle；fixed 用当前样式统一测量，切句不改变折行 |
| lineMotion | LyricLineMotion | 同步；delay/maxDelay/maxLag 控制错位，waveAmplitude/waveDuration 控制波浪 |
| wordEffects | LyricWordEffects | 默认关闭上弹、悬浮和时间模拟，可独立复用 |
| distanceBlur | LyricDistanceBlur | maxSigma: 0；按焦点距离增加 blur，whenBrowsing 决定浏览时是否保留 |
| jumpScrollThreshold | double? | null；大于此视口高度倍数时直接定位，Apple Music 为 1 |
| translationInheritsTextStyle | bool | true；false 时翻译直接继承环境样式，Apple Music 为 false |
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
  clearJumpScrollThreshold: true,
  clearResumeDelay: true,
  clearEmptyBuilder: true,
  clearSelectionBackgroundBuilder: true,
  clearSelectionForegroundBuilder: true,
);
```

同一个属性同时传值与 clear 标记会抛 `ArgumentError`。预设按值比较；builder / 自定义动画回调按函数相等性比较。时间与距离不能为负；fraction 范围为 0…1。构造器的数值断言与使用时的时长校验会拒绝无效参数。

吸附和恢复计时独立：afterScroll 等滚动停止后开始吸附倒计时；onDragPause 也允许拖动停顿时吸附；手指仍在拖动中时直接校正位置，以保留当前手势，松手后的吸附使用 scrollAnimation。resumeDelay 从本次浏览停止后计时。若恢复先发生，会取消尚未执行的吸附。新的手动交互重新开始计时。

内置预设直接复用 Lyric Studio 中的七种风格，都是可通过 `copyWith` 调节的 `const LyricPreset`：

| 预设 | 文字与布局 | 高亮与动效 |
| --- | --- | --- |
| `LyricPresets.moss`（苔原） | 起始侧对齐，正文 23 / 当前句 30，主句锚点 40% | 浅绿逐字高亮，轻盈浮升，550ms 滚动 |
| `LyricPresets.aurora`（极光，默认） | 居中，正文 23 / 当前句 28，主句锚点 50% | 薄荷绿至淡紫渐变，反向弧线交接，550ms 滚动 |
| `LyricPresets.appleMusic` | 起始侧对齐、固定折行、32px 主句、38% 锚点 | 错位、波浪、距离模糊、2.5px 上弹、±1.4px 悬浮 |
| `LyricPresets.cascade`（瀑布） | 起始侧对齐、固定折行、28px 主句 | 65ms 行间延迟、三段落位，不启用字词运动 |
| `LyricPresets.pulse`（跃动） | 居中、固定折行、30px 主句 | 180ms / 5px 逐字上弹、弹簧回落，不启用悬浮 |
| `LyricPresets.drift`（浮游） | 居中、固定折行、26px 主句、宽松行距 | ±2px 悬浮、7.2s 周期、斜向缓慢漂移 |
| `LyricPresets.cinema`（银幕） | 仅当前条目，当前句 32 / 译文 14，译文间距 18 | 暖色逐字高亮，雾化对焦与交叉淡出；无滚动、无边缘淡出，默认不可交互 |

七种预设面向深色背景，背景由应用提供，不包含 demo 的舞台装饰或播放器。旧的 `leading` / `centered` / `singleLine` 名称已移除。想跟随应用文字主题可以从 `const LyricPreset()` 开始，其构造器默认值保持不变。

## LyricCountdown

`LyricPreset.countdown` 默认是 `const LyricCountdown()`；所有内置预设与 Studio 风格默认启用，并提供适配后的圆点样式。使用 `const LyricCountdown.none()` 关闭。配置参与 preset 的值比较和 `copyWith`。

计时只有三个配置：

| 参数 | 默认值 / 语义 |
| --- | --- |
| dotCount | 3；正整数，各点均分消退总时长 |
| dotDuration | 3 秒；整组圆点消退总时长，必须为正；空白不足时不显示 |
| breathDuration | 0；消退前最多呼吸等待多久，非负；仅使用预留消退时长后多余的空白 |

另保留启用开关与预设样式字段，供代码定制，Studio 的小圆点区域仅展示开关与上述三项：

| 参数 | 默认值 / 语义 |
| --- | --- |
| enabled | true；`.none()` 为 false |
| direction | `LyricCountdownDirection.startToEnd`：跟随文字方向；`leftToRight` / `rightToLeft`：固定物理消退方向，不改变内容对齐 |
| dotSize / dotSpacing | 8 / 8；直径与水平间距，逻辑像素 |
| color | null：沿用解析后的当前句文字颜色；内置预设提供主题色 |
| inactiveColor | null：当前圆点颜色的 20% 不透明度 |
| height / spacing | 24 / 16；倒计时行高、距下一句的留白；放不下时等比缩小 |

空白区间 `[gapStart, gapEnd)` 至少要有 `dotDuration`。显示起点为 `max(gapStart, gapEnd - dotDuration - breathDuration)`，消退从 `gapEnd - dotDuration` 开始，下一句开始时消失。短空白整段跳过；刚好够时没有呼吸；改变点数不改变总时长。呼吸周期为 1.6 秒，按播放时间计算，暂停冻结、seek 即时更新，并在逐点消退开始前平滑恢复正常大小和亮度；减少动画或关闭 `TickerMode` 时保持静态。

圆点出现时独占播放焦点，所有歌词使用非焦点样式，包括仍在退出动画中的上一句。Controller 的激活行和播放时间保持原样；视图此时的 `activeIndex` 为 -1。正文开始后恢复该句的激活样式。滚动模式仅在显示区间内为圆点留出行高，隐藏后不占位；沿用歌词滚动与排版过渡，跟随到 `activeAnchor`，并与下一句共用行位移与波浪动画。水平位置沿用 `contentAlignment` 和方向性边距。单行模式以圆点暂时替换歌词，不显示 `emptyBuilder`。手动浏览时圆点随歌词滚动，恢复跟随后回到锚点。

空白检测使用歌词时间轴：从 0 到第一条非空歌词可形成前奏；行间优先使用有效的 `LyricLine.end`，其次使用全部逐字时间的最大结束时间。结束时间不全时沿用下一条严格更晚的时间戳，因此普通 LRC 必须用空白条目标记间奏。重叠 / 同时间戳歌词要等所有已知演唱时段结束；纯空白文档和最后一句之后不倒计时。

可通过 `LyricDocument.vocalStart` 提供首句正文起点，例如 QQ 音乐的 `startTs` 毫秒值。已知开唱点时，将 **0 到首句正文开始** 作为可用前奏，借用其中的署名歌词时间补足消退时长；署名的起止时间与增删不缩短前奏。整个前奏仍不足 `dotDuration` 时不显示。文本、逐字时间和 Controller 激活行不变，窗口开始前正常跟随署名。STAY 的前奏为 `[0, 11438)` 毫秒。

定位首句时允许开始时间比提示早至多 9 毫秒，以兼容 LRC 导出的厘秒截断；倒计时结束对齐该句实际时间戳。没有后续非空正文行时不生成倒计时，开唱点为 0 时没有前奏。后续间奏按正文结束时间检测；省略 `vocalStart` 时从第一条非空歌词检测。文档 offset 与 Controller.timeOffset 同时生效。

清除 nullable 样式字段使用 `clearColor` / `clearInactiveColor`，同一属性不能同时传值与清除标记。Studio 可导出全部圆点配置。倒计时不提供 Widget builder 或独立圆点 Widget。

旧的 `LyricCountdownMode`、`minimumGap`、`leadIn`、`showIntro` / `showInterludes`、`extraDuration` 已移除。原每点一秒配置可改为 `dotDuration: Duration(seconds: dotCount)`，原额外等待改为 `breathDuration`。

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

## 播放切句与效果组合

四层配置互相独立：`scrollAnimation` 决定列表锚点的移动；`lineMotion` 在滚动位置上叠加每行延迟和波浪；`lineTransition` 插值行状态；`wordEffects` 控制段落内的字词运动，`highlight` 控制点亮。`wordEffects.floatMode` 默认为 `LyricFloatMode.highlighted`，只让高亮已到达的字素簇悬浮，随该字符的高亮进度柔和启用；尚未高亮及未匹配逐字时间的字符不悬浮。设为 `LyricFloatMode.all` 可让当前句全部文字悬浮，关闭高亮后也保留此效果。没有逐字时间且未模拟时，当前句整句高亮并悬浮。两种模式均不改变逐字上弹。

```dart
final preset = LyricPresets.appleMusic.copyWith(
  lineTransition: const LyricLineTransition.effects([
    LyricLineEffect.slide(Offset(24, 8)),
    LyricLineEffect.scale(.9),
    LyricLineEffect.fade(.3),
    LyricLineEffect.blur(2),
  ], enterDuration: Duration(milliseconds: 300),
     exitDuration: Duration(milliseconds: 200)),
);
```

### 独立切句预设

`LyricLineTransitions` 提供可直接复用的 `const LyricLineTransition`。
`copyWith` 调整时长和曲线会保留原轨迹；切句不会修改列表滚动或逐字效果。

| 配置 | Studio 名称 | 运动方式 |
| --- | --- | --- |
| `rise` | 轻盈浮升 | 从下方轻升并放大到位 |
| `paper` | 纸页滑入 | 横向移动先行，透明度稍后跟上 |
| `spring` | 弹簧回落 | 放大超过目标，二次回弹后收稳 |
| `orbit` | 弧光掠入 | 新旧句沿相反方向的二维弧线交接 |
| `pendulum` | 钟摆回落 | 三次逐渐减弱的横向摆动，相邻句反相 |
| `zoom` | 镜头推进 | 略大、虚焦的文字收进清晰平面 |
| `step` | 分段跃迁 | 水平方向三次短移动与停顿，保持上下行距，段间位置连续 |
| `drift` | 余韵漂移 | 缓慢斜向运动，退出方向反转 |
| `focus` / `cinematic` | 雾化交叠 | 先对焦后显现；前者保留邻行，后者完全淡出 |

基础选项为 `none`、`classic`、`fade`、`scale`、`slide`、`blur`、`slideFade` 和
`appleMusic`。Studio 共展示 17 个选项；雾化交叠根据当前显示模式选择 `focus`
或 `cinematic`。直接使用库时，`cinematic` 适合 `activeLine`，其失活透明度为 0。

整套风格默认搭配：苔原 → rise，极光 → orbit，Apple Music → appleMusic，
瀑布 → step，跃动 → spring，浮游 → drift，银幕 → cinematic。
Studio 的字刊、霓虹、来信、频率则分别使用 paper、zoom、pendulum、step。

效果值定义失活状态；激活目标是 offset=0、scale=1、opacity=1、blurSigma=0。组合位移相加、缩放及透明度相乘、模糊按 `sqrt(sum(sigma²))` 合并。`effects` 列表应使用 const 或不可变列表。坐标先围绕内容对齐点缩放，再位移；透明度和局部模糊作用于主句、翻译组成的整行离屏层，sigma 使用行局部像素并随行缩放。距离模糊也按方差与行过渡模糊合并。颜色和高亮权重由 `activity`（0…1）插值。默认 `LyricLineTransition()` 保留双样式的尺寸过渡；`none()` 立即切换。用 `lineTransition.copyWith(...)` 调整时长/曲线可保留已有组合和回调。

滚动列表中的淡出值应大于 0，以保留其他行的可读性；`fade(0)` 会完全隐藏失活行，适合单行交叉淡出。浏览时模糊焦点平滑移向选中行，并消除焦点行的切句模糊；播放高亮仍跟随播放位置。选择变化和恢复跟随不会重启播放切句动画，自定义回调只作用于激活状态正在变化的行，其他行的排版位移单独插值。

自定义示例（`dart:math` 以 `math` 导入）：

```dart
final custom = LyricLineTransition.custom((context) {
  final state = LyricLineVisualState.lerp(
      context.from, context.to, context.progress);
  return LyricLineVisualState(
    offset: state.offset + Offset(16 * math.sin(math.pi * context.progress), 0),
    scale: state.scale,
    opacity: state.opacity,
    blurSigma: state.blurSigma,
    activity: state.activity,
  );
}, maxDisplacement: 16, maxBlurSigma: 0, maxScale: 1);
```

`LyricLineTransitionContext` 包含经过曲线变换的 progress、捕获的 from、目标 to、index、activeIndex、previousActiveIndex、entering、未应用行状态变换的 lineRect 和 viewportSize。回调必须纯净，不得写入播放器或 widget 状态。库负责时钟、裁剪、绘制、点击与选择，缓存同一帧的返回状态。进度端点直接采用 from/to；中途自定义输出必须有限，scale 必须为正。库将位移、缩放和模糊限制在声明范围及已捕获的起始范围内，将透明度/activity 限制在 0…1；越界效果不会无限扩大离屏层。

连续切句从当前视觉状态重新定向，退场逐字进度冻结在上次采样的位置。没有 seek 原因字段，因此所有播放索引变化使用同一策略，不猜测是否为自然播放或播放器 seek。点击调用业务回调，可触发行波浪；恢复跟随和主动定位复用同一滚动策略。超过 jumpScrollThreshold 时清除残留行间位移，直接定位。双样式模式保留两套字体的折行/行高变化；要求长句切换时完全保持段落几何时使用 fixed。

activeLine 使用带淡出的效果（失活 opacity < 1）或自定义回调时，暂存仍在退场的段落，完成后释放；连续切换回旧句可复用段落。Cinema 默认使用交叉淡出，退场完成后只保留当前条目。开启 `MediaQueryData.disableAnimations` 或关闭 `TickerMode` 会收敛动画，悬浮时钟停止；暂停播放器不会停止悬浮。上弹使用播放时间，悬浮使用本视图时钟，两者不推动播放。

未启用逐字效果时不建立字素缓存；字词/字素分片按需复用已排版段落。普通帧不重新测量文字。CPU picture recording benchmark 不能验证 GPU 模糊、离屏层或悬浮合成的开销，实际设备仍需 profile。

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
| lineRect | 动画后的行区域，包含主文本和翻译，不含行距；双样式模式含水平 padding，固定模式为内容区域 |
| contentRect | 使用相同动画变换的内容区域 |
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

`LyricDocument(lines: ..., tags: ..., offset: ..., vocalStart: ...)` 防御性复制集合并按开始时间稳定排序。省略 offset 时从 LRC `[offset:毫秒]` 标签读取；显式 offset 优先。可选的 `vocalStart` 是非负 `Duration`，用于前奏倒计时识别，默认 null；它不会裁剪或重写歌词。`copyWith` 使用具名参数，null 保留原值，`clearVocalStart: true` 清除正文起点，同时设置与清除会抛出 `ArgumentError`。`LyricLine` 的 words 也不可修改。

`LyricDocument.parse(text, translation: ..., parser: ..., vocalStart: ...)` 自动检测 LRC / YRC / QRC / fallback。`LyricController.load` 同样支持 `vocalStart`。正文起点由调用方传入，纯歌词文件不包含 QQ 接口的这个字段。自定义解析器继承 `LyricParser`，实现 `canParse` 和 `parse(String mainLyric, {String? translationLyric})`。逐字时间相对整首歌词，而非相对所在行。`LrcToQrcUtil` 继续用于格式转换。

## Apple Music-inspired view

`AppleMusicLyricView(controller:, style:, viewId:, onLineTap:, onSelectionChanged:, onFollowChanged:)` 是 `LyricView` 的便捷包装。推荐 `LyricView(preset: LyricPresets.appleMusic, controller: controller)`。style 通过 `toPreset()` 转换为相同的四层配置。尺寸由外层布局提供，必须具有有限宽高；包装默认显式使用 `const AppleMusicLyricStyle()`，不继承 Scope。

它复用 `LyricDocument`、解析器、`LyricController` 和回调 details 类型。普通视图与 Apple Music 视图可以使用同一个 controller；每个 viewId 在该 controller 内唯一，各自保存浏览、选中和动画状态。`resumeFollow` / `scrollToLine` 的 viewId 路由规则保持一致。

### AppleMusicLyricStyle

配置不可变，具有值比较和 `copyWith`。`copyWith` 的 null 参数保留旧值；`clearResumeDelay`、`clearEmptyBuilder`、`clearSelectionBackgroundBuilder`、`clearSelectionForegroundBuilder` 清除对应可空值，同时设置与清除会抛出 `ArgumentError`。

| 参数 | 默认值 / 含义 |
| --- | --- |
| `textStyle` / `translationTextStyle` | 正文 32、w700；翻译 16、w500；浅色文字适合深色背景，分别与环境 DefaultTextStyle 合并 |
| `textAlign` / `contentAlignment` | `start`，随文字方向解析；正文与翻译分别对齐 |
| `padding` / `lineSpacing` / `translationSpacing` | 水平 24 / 24 / 8 逻辑像素 |
| `activeAnchor` / `selectionAnchor` | 视口高度 38%，对准正文中心 |
| `highlight` | 白色逐字高亮，尾部渐隐宽度 16；复用 `LyricHighlight` 的纯色、渐变和关闭配置 |
| `edgeFade` | 顶部 10%、底部 15%；复用 `LyricEdgeFade` |
| `inactiveScale` / `inactiveOpacity` | 0.92 / 0.45；比例分别限制为 (0, 1] 和 [0, 1] |
| `maxBlurSigma` / `blurSigmaPerLine` | 4 / 1；与焦点相隔的行数决定模糊，设 maxBlurSigma 为 0 关闭 |
| `blurWhenBrowsing` | false；默认在拖动、滚动和停留选择期间保持所有歌词及翻译清晰，恢复播放跟随后重新启用距离模糊；设为 true 可在浏览时保留模糊 |
| `wordLift` / `wordPopDuration` | Word Pop：唱到字词时上弹并保持，默认高度 2.5 逻辑像素、上升时长 900ms，行失活时回到原位；幅度或时长设 0 单独关闭 |
| `characterFloatAmplitude` | Character Float：围绕上弹后位置的上下偏移幅度，默认 ±1.4 逻辑像素，不改变上弹高度；设 0 关闭漂浮并保留上弹高度 |
| `characterFloatPeriod` | 悬空后的微动标称周期 6000ms，周期之间轻微变化，不会每轮落回原位；设 0 关闭 |
| `characterFloatStagger` | 相邻字素簇沿阅读顺序连续错相 180ms；不受逐字时间片段边界影响 |
| `characterFloatMode` | `LyricFloatMode.highlighted`；默认只悬浮高亮已到达的字符，随高亮进度柔和启用；`all` 让当前句全部文字悬浮，包括未高亮文字；对应统一预设的 `wordEffects.floatMode` |
| `simulateWordTiming` | true；只为缺少真实 words 的行模拟时间 |
| `lineAnimation` | 250ms，easeOutCubic；控制大小、透明度和模糊焦点过渡 |
| `scrollAnimation` | 500ms，easeOutCubic；复用固定、按距离和自定义 resolver 的滚动配置；实际滚动距离超过一屏高度时直接定位，不使用滚动时长、行间延迟或波浪 |
| `waveDelay` / `maxWaveDelay` | 每相隔一行延迟 35ms，最多 140ms |
| `waveDuration` / `waveAmplitude` | 波浪持续 600ms、幅度 12；波浪为歌词行位移，不绘制圆形涟漪 |
| `maxLineLag` | 错位跟随最多 64 逻辑像素，限制大跨度 seek 时的行间位移；设 0 关闭 |
| `interactive` / `resumeOnTap` | true / true |
| `selectionSnapMode` / `selectionSnapDelay` | none / 320ms；默认不将选中行自动吸附到锚点，可设为 afterScroll 或 onDragPause 开启 |
| `resumeDelay` | 浏览停止 3 秒后恢复跟随；设 null 关闭自动恢复 |
| `emptyBuilder` / selection builders | 默认 null；沿用 LyricSelectionDetails，几何坐标相对于当前 view，跟随动画更新 |

距离和时长须非负、距离须有限。关闭全部位移动画可将 `lineAnimation.duration`、`scrollAnimation` 的时长和 `waveDuration` 设为零，并将 `wordLift`、`characterFloatAmplitude` 设为零；将 `inactiveScale` 设为 1 取消大小差异。Word Pop 与 Character Float 的位移相加，参数分别独立控制：上弹完成后，抬升量在 `wordLift ± characterFloatAmplitude` 内变化（默认 1.1–3.9px）；`waveAmplitude` 等参数控制行切换/点击时的整行波浪。

### 时间与绘制行为

- 真实 `LyricWord` 时间优先，按原始时间片段逐步高亮。Word Pop 在 word.start 开始、经过 wordPopDuration 上升到 wordLift 并保持，不随长音持续时间拉长，也不会在上升结束后回落。它由播放时间驱动，暂停时保持进度，seek 后直接采样目标位置，不补播跳过的上弹。无 end 的 word 使用下一 word 的 start 或行结束时间计算高亮；仍无结束时间时瞬时完成高亮。
- Character Float 使用视图自己的动画时钟，播放暂停时仍保持已高亮字符的呼吸感，不修改播放位置。悬浮波形以 0 为中心，在 Word Pop 位置上叠加正负偏移，不承担抬升高度。相邻字符采样同一条连续传播的柔和波形，周期之间带有轻微变化；默认 `highlighted` 模式按每个字素的实际高亮边界（含尾部渐隐、换行及 RTL 方向）柔和启用悬浮，未高亮字符保持无悬浮位移。关闭高亮会停止默认模式的悬浮；`all` 模式可保留原先全句悬浮。没有逐字时间且未模拟时整句高亮并悬浮，没有上弹时围绕原始基线漂浮。行失活时两种位移随 activity 回到原位。隐藏、减少动态效果、无可悬浮字符或激活行移出绘制范围时停止时钟。widget 测试应使用有界 `pump`，或关闭悬浮后再 `pumpAndSettle`。
- 普通 LRC 按 Unicode 字素簇均分时间，保留 emoji 和组合字符。行结束时间优先取有效 `line.end`，其次取下一条严格更晚的开始时间；未知结束时间的行整行高亮。模拟仅为视觉近似，不修改 controller.document。
- 所有行按正文和翻译的完整尺寸测量，上方预留两种效果叠加的空间，下方预留悬浮向下偏移的空间。非当前行通过缩放绘制变小，换行和行占位不会随动画改变；翻译跟随整行过渡，不逐字上弹或悬浮。字符分片保留完整字素簇和原段落排版，字符坐标仅在需要时计算并缓存。
- 跟随模式以播放行为模糊焦点，浏览模式默认保持清晰；设为 `blurWhenBrowsing: true` 后，浏览时以选中行为模糊焦点。统一预设对应 `distanceBlur.whenBrowsing`，Apple Music 默认也为 false。只绘制可见行及有限的动画余量；模糊图层局限于对应行，字词坐标和文字遮罩按需缓存。
- 点击使用动画后的行位置命中，回调中的 seekPosition 已扣除文档与 controller 偏移，并限制为非负。调用方负责播放器 seek；组件自身不抢先修改播放位置。
- 手动拖动会接管正在进行的滚动；连续 seek 从当前视觉位置重新定向。播放跳转、`scrollToLine` 或恢复跟随时，若目标距离当前滚动位置超过一屏高度，则直接定位并清除旧的行间错位残留；一屏以内保留滚动动画。切换文档、controller 或 viewId 会清理旧浏览状态与动画；旧 selection builder 回调失效。
- `TickerMode` 关闭时停止视图动画与采样资格；系统 `MediaQuery.disableAnimations` 打开时取消位移与缩放过渡，仍按播放器时间高亮。

背景、封面和播放控制由宿主提供。Studio 通过同一预设列表与动效面板展示所有风格；舞台的时间模式菜单可切换原始逐字和普通 LRC。普通 LRC 预览复用播放器时间、移除逐字和行结束时间，以下一行推断时长，不修改原始文档。
