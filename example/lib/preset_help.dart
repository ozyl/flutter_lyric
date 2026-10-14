// @dart=3.8

/// Outcome first; the code icon in the inspector exposes the matching API.
const presetHelp = <String, ({String api, String description})>{
  '显示圆点倒计时': (
    api: 'countdown.enabled',
    description: '在开唱前或间奏期间显示；暂停时保持，下一句开始时消失。',
  ),
  '小圆点数量': (
    api: 'countdown.dotCount',
    description: '整组圆点依次消退，各点均分小圆点时长；改变数量不会改变总时长。',
  ),
  '小圆点时长': (
    api: 'countdown.dotDuration',
    description:
        '整组圆点消退的总时长，最后一个点在下一句开始时完成。空白不足时不显示；已知 startTs 时可借用 0 到开唱点的署名时间。',
  ),
  '小圆点呼吸时长': (
    api: 'countdown.breathDuration',
    description: '消退前最多呼吸等待多久，仅使用空白段多余的时间。设为 0 关闭呼吸，不压缩消退时长。',
  ),
  '正文大小': (
    api: 'textStyle.fontSize',
    description: '正文的基础字号；当前句未单独设置字号时也会沿用。单位为 Flutter 逻辑像素。',
  ),
  '当前句大小': (
    api: 'activeTextStyle.fontSize',
    description: '正在播放的歌词字号；未设置时沿用正文大小。',
  ),
  '当前句字重': (api: 'activeTextStyle.fontWeight', description: '数值越大，当前句的笔画越粗。'),
  '正文透明度': (api: 'textStyle.color', description: '非当前句的可见程度；0% 透明，100% 不透明。'),
  '当前句文字透明度': (api: 'activeTextStyle.color', description: '当前句尚未被高亮覆盖的文字透明度。'),
  '当前句文字颜色': (
    api: 'activeTextStyle.color',
    description: '当前句的基础文字颜色；逐字高亮会覆盖已唱部分。',
  ),
  '译文大小': (
    api: 'translationTextStyle.fontSize',
    description: '每句歌词下方译文的字号；歌词没有译文时不显示。',
  ),
  '当前译文大小': (
    api: 'activeTranslationTextStyle.fontSize',
    description: '正在播放句的译文字号；未设置时沿用普通译文。',
  ),
  '译文间距': (api: 'translationSpacing', description: '正文与它下方译文之间的垂直距离。'),
  '显示方式': (api: 'displayMode', description: '多行展示可浏览的歌词列表；仅当前句也支持长句换行和译文。'),
  '长句换行方式': (api: 'layoutMode', description: '决定歌词切换为当前句时，长句的换行位置是否随字号变化。'),
  '文字对齐': (api: 'textAlign', description: '控制同一句长歌词换行后，每行文字靠左、居中或靠右。'),
  '内容对齐': (api: 'contentAlignment', description: '控制整块歌词在可用宽度内的位置；短句更容易看出区别。'),
  '行间留白': (api: 'lineSpacing', description: '两句完整歌词之间的距离，不是同一句换行后的行高。'),
  '水平边距': (api: 'padding', description: '歌词区域左右两侧的留白；会影响长句能放下多少字。'),
  '切句动画': (api: 'lineTransition', description: '播放进入下一句时，新旧当前句的缩放、位移、明暗等变化。'),
  '行间运动': (api: 'lineMotion', description: '同步：整列一起移动；错位：相邻句延迟跟进；波浪：再叠加上下起伏。'),
  '行间延迟': (api: 'lineMotion.delay', description: '相邻歌词开始跟随滚动的时间差；越大越有层层跟进的感觉。'),
  '最大延迟': (api: 'lineMotion.maxDelay', description: '距离当前句较远的歌词最多延后多久开始移动。'),
  '行间错位': (api: 'lineMotion.maxLag', description: '歌词相对整体滚动轨迹的最大偏移距离。'),
  '波浪幅度': (
    api: 'lineMotion.waveAmplitude',
    description: '滚动时额外上下起伏的距离；0 表示关闭。',
  ),
  '波浪时长': (api: 'lineMotion.waveDuration', description: '一次波浪起伏收稳所需的时间。'),
  '超过一屏直接定位': (
    api: 'jumpScrollThreshold',
    description: '目标距离超过一个歌词区域高度时跳转，避免长距离滚动。',
  ),
  '远处模糊': (
    api: 'distanceBlur.maxSigma',
    description: '离当前句越远越模糊；此值是模糊上限，0 表示关闭。',
  ),
  '滑动选择时保持清晰': (
    api: 'distanceBlur.whenBrowsing',
    description: '开启后，手动浏览歌词时暂时取消距离模糊，方便选句。',
  ),
  '逐字上弹': (api: 'wordEffects.lift', description: '唱到一个字时向上抬起的距离；0 表示关闭。'),
  '上弹时长': (api: 'wordEffects.liftDuration', description: '一个字从抬起到回落的动画时长。'),
  '逐字悬浮': (
    api: 'wordEffects.floatAmplitude',
    description: '文字持续轻轻上下漂浮的距离；0 表示关闭。',
  ),
  '悬浮模式': (
    api: 'wordEffects.floatMode',
    description: '默认仅高亮文字悬浮，尚未点亮的字符保持原位；也可让当前句全部文字悬浮。关闭高亮时，仅全部文字模式保留悬浮。',
  ),
  '悬浮周期': (api: 'wordEffects.floatPeriod', description: '完成一次上下漂浮所需的时间；越大越缓慢。'),
  '相邻字符延迟': (
    api: 'wordEffects.floatStagger',
    description: '相邻字符悬浮的时间差，避免所有字同时起伏。',
  ),
  'LRC 模拟逐字时间': (
    api: 'wordEffects.simulateTiming',
    description: '普通 LRC 没有逐字时间时，在句子时长内估算；不是真实逐字时间。末句无结束时间时整句点亮。',
  ),
  '高亮方式': (api: 'highlight', description: '给已唱过的文字叠加纯色或渐变；关闭后保留基础文字颜色。'),
  '高亮颜色': (api: 'highlight.color', description: '已唱部分的文字颜色，独立于当前句文字透明度。'),
  '渐变起点': (
    api: 'highlight.gradient.colors',
    description: '已唱文字渐变的起始颜色，默认从左向右过渡。',
  ),
  '渐变终点': (api: 'highlight.gradient.colors', description: '已唱文字渐变的结束颜色。'),
  '高亮尾部柔化': (
    api: 'highlight.tailFadeWidth',
    description: '已唱与未唱文字交界处的渐隐宽度；0 为清晰分界。',
  ),
  '滚动时长 · 100px': (
    api: 'scrollAnimation',
    description: '滚动 100 逻辑像素的参考时长；按距离计时的配置会同比缩放。0 为立即定位。',
  ),
  '滚动曲线': (
    api: 'scrollAnimation.curve',
    description: '控制滚动的速度变化，如匀速、逐渐减速或末尾回弹。',
  ),
  '进入时长': (
    api: 'lineTransition.enterDuration',
    description: '一句歌词变为当前播放句的动画时长，与列表滚动时长独立。',
  ),
  '退出时长': (api: 'lineTransition.exitDuration', description: '上一句变回普通歌词的动画时长。'),
  '边缘淡出': (api: 'edgeFade', description: '靠近歌词区域顶部、底部时逐渐透明，减少裁切感。'),
  '淡出单位': (api: 'edgeFade', description: '比例随歌词区域高度变化；像素使用固定的逻辑像素距离。'),
  '顶部淡出': (api: 'edgeFade.top', description: '从歌词区域顶部向内的渐隐范围；越大，透明过渡越长。'),
  '底部淡出': (api: 'edgeFade.bottom', description: '从歌词区域底部向内的渐隐范围。'),
  '允许手势交互': (api: 'interactive', description: '允许拖动浏览和点按歌词；关闭后只展示播放效果。'),
  '选句吸附': (
    api: 'selectionSnapMode',
    description: '浏览后将选中句移到选句停留位置；吸附不会跳转播放进度。',
  ),
  '吸附等待': (api: 'selectionSnapDelay', description: '停止滚动或拖动停顿后，等待多久再将选中句对齐。'),
  '自动恢复跟随': (api: 'resumeDelay', description: '手动浏览一段时间后，自动回到当前播放句；关闭需手动返回。'),
  '恢复等待': (api: 'resumeDelay', description: '停止浏览后等待多久，再让歌词自动跟随播放。'),
  '点按后恢复跟随': (
    api: 'resumeOnTap',
    description: '点按歌词后恢复跟随。播放跳转需接入者在 onLineTap 中实现。',
  ),
};

({String api, String description})? helpForPresetControl(String label) {
  final known = presetHelp[label];
  if (known != null) return known;
  for (final (prefix, field) in [
    ('当前句', 'activeAnchor'),
    ('选择句', 'selectionAnchor'),
  ]) {
    if (label == '$prefix定位方式') {
      return (
        api: field,
        description: '从歌词区域顶部计算：比例 50% 在正中，像素 160 在距顶部 160 逻辑像素处。切换单位会重设位置。',
      );
    }
    if (label == '$prefix位置') {
      return (
        api: '$field.position',
        description: prefix == '当前句'
            ? '自动跟随播放时，当前句停留的垂直位置。'
            : '手动浏览时用于选句和吸附的垂直位置。',
      );
    }
    if (label == '$prefix对齐基准') {
      return (
        api: '$field.target',
        description: '将正文中心、译文中心或正文加译文的整体中心，对齐到上面的停留位置。',
      );
    }
  }
  return null;
}
