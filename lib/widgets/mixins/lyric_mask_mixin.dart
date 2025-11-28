import 'package:flutter/material.dart';
import 'package:flutter_lyric/core/lyric_style.dart';

/// 负责歌词遮罩/渐变效果的 Mixin
mixin LyricMaskMixin<T extends StatefulWidget> on State<T> {
  LyricStyle get style;
  Size get lyricSize;

  /// 如果需要，包装遮罩效果
  Widget wrapMaskIfNeed(Widget child) {
    if (style.fadeRange == null) {
      return child;
    }
    var top = style.fadeRange!.top;
    var bottom = style.fadeRange!.bottom;
    if (top > 1) {
      top = top / lyricSize.height;
    }
    if (bottom > 1) {
      bottom = (bottom / lyricSize.height);
    }
    top = top.clamp(0, 1);
    bottom = bottom.clamp(0, 1);
    return ShaderMask(
      shaderCallback: (Rect bounds) {
        return LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: const [
            Colors.transparent, // 顶部渐隐
            Colors.black, // 中间正常显示
            Colors.black, // 中间正常显示
            Colors.transparent, // 底部渐隐
          ],
          stops: [
            0.0, // 顶部开始透明
            top, // 渐变到完全显示
            1 - bottom, // 开始向底部渐隐
            1.0, // 底部完全透明
          ],
        ).createShader(bounds);
      },
      blendMode: BlendMode.dstIn,
      child: child,
    );
  }
}
