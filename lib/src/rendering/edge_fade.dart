import 'dart:ui' as ui;
import 'package:flutter/widgets.dart';
import 'package:flutter/rendering.dart';
import '../preset/lyric_effects.dart';

class EdgeFade {
  Rect? _bounds;
  LyricEdgeFade? _fade;
  ui.Shader? _shader;
  ui.Shader shader(Rect bounds, LyricEdgeFade fade) {
    if (_bounds != bounds || _fade != fade) {
      final stops = fade.resolve(bounds.height);
      _shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: const [
            Color(0x00FFFFFF),
            Color(0xFFFFFFFF),
            Color(0xFFFFFFFF),
            Color(0x00FFFFFF)
          ],
          stops: [
            0,
            stops[0],
            1 - stops[1],
            1
          ]).createShader(bounds);
      _bounds = bounds;
      _fade = fade;
    }
    return _shader!;
  }
}

/// Always keep this widget in the tree so enabling/disabling a fade does not
/// replace the Scrollable state. Flutter owns the mask layer and its resources.
class LyricEdgeMask extends SingleChildRenderObjectWidget {
  final LyricEdgeFade fade;
  final EdgeFade cache;
  const LyricEdgeMask(
      {Key? key,
      required this.fade,
      required this.cache,
      required Widget child})
      : super(key: key, child: child);
  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderEdgeMask(fade.enabled, (bounds) => cache.shader(bounds, fade));
  @override
  void updateRenderObject(
      BuildContext context, covariant _RenderEdgeMask renderObject) {
    renderObject.enabled = fade.enabled;
    renderObject.shaderCallback = (bounds) => cache.shader(bounds, fade);
  }
}

class _RenderEdgeMask extends RenderShaderMask {
  bool _enabled;
  _RenderEdgeMask(this._enabled, ShaderCallback callback)
      : super(shaderCallback: callback, blendMode: BlendMode.dstIn);
  set enabled(bool value) {
    if (value == _enabled) return;
    _enabled = value;
    markNeedsCompositingBitsUpdate();
    markNeedsPaint();
  }

  @override
  bool get alwaysNeedsCompositing => _enabled && child != null;
  @override
  void paint(PaintingContext context, Offset offset) {
    if (_enabled) {
      super.paint(context, offset);
    } else {
      layer = null;
      if (child != null) context.paintChild(child!, offset);
    }
  }
}
