import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import '../view/lyric_view_session.dart';

class LyricViewport extends LeafRenderObjectWidget {
  final LyricViewSession session;
  final ViewportOffset offset;
  const LyricViewport({Key? key, required this.session, required this.offset})
      : super(key: key);
  @override
  RenderLyricViewport createRenderObject(BuildContext context) =>
      RenderLyricViewport(session, offset);
  @override
  void updateRenderObject(
      BuildContext context, RenderLyricViewport renderObject) {
    renderObject.update(session, offset);
  }
}

/// Scrollable supplies Flutter's drag, ballistic and wheel physics. This box
/// paints only intersecting entries, without constructing a widget per lyric.
class RenderLyricViewport extends RenderBox {
  LyricViewSession session;
  ViewportOffset _offset;
  late final Listenable _fonts;
  bool _layingOut = false;
  int? _semanticIndex;
  RenderLyricViewport(this.session, ViewportOffset offset) : _offset = offset {
    session.attachOffset(offset);
    final PaintingBinding? binding = PaintingBinding.instance;
    _fonts = binding!.systemFonts;
  }
  void update(LyricViewSession value, ViewportOffset offset) {
    if (!identical(session, value)) {
      if (attached) session.removeListener(_changed);
      session.detachOffset(_offset);
      session = value;
      if (attached) session.addListener(_changed);
    }
    _offset = offset;
    session.attachOffset(offset);
    markNeedsLayout();
    markNeedsPaint();
  }

  void _changed() {
    if (_layingOut) return;
    if (_semanticIndex != session.activeIndex) {
      _semanticIndex = session.activeIndex;
      markNeedsSemanticsUpdate();
    }
    if (session.needsLayout) {
      markNeedsLayout();
      markNeedsSemanticsUpdate();
    } else {
      markNeedsPaint();
    }
  }

  void _fontsChanged() => session.fontsChanged();
  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    session.attachOffset(_offset);
    session.addListener(_changed);
    _fonts.addListener(_fontsChanged);
  }

  @override
  void detach() {
    session.detachOffset(_offset);
    session.removeListener(_changed);
    _fonts.removeListener(_fontsChanged);
    super.detach();
  }

  @override
  bool get isRepaintBoundary => true;
  @override
  bool get sizedByParent => false;
  @override
  void performLayout() {
    if (!constraints.hasBoundedWidth || !constraints.hasBoundedHeight) {
      throw FlutterError(
          'LyricView requires bounded width and height. Wrap it in SizedBox or Expanded.');
    }
    size = constraints.biggest;
    _layingOut = true;
    try {
      session.layoutViewport(size);
    } finally {
      _layingOut = false;
    }
  }

  @override
  bool hitTestSelf(Offset position) => true;
  @override
  void paint(PaintingContext context, Offset offset) {
    if (size.isEmpty) return;
    final canvas = context.canvas;
    canvas.save();
    canvas.translate(offset.dx, offset.dy);
    final painter = session.painter;
    if (painter != null) {
      painter.paint(canvas, size);
    } else {
      // Active-line intros have a countdown before the first lyric paragraph.
      session.countdownPainter?.paint(canvas, size);
    }
    canvas.restore();
  }

  @override
  void describeSemanticsConfiguration(SemanticsConfiguration config) {
    super.describeSemanticsConfiguration(config);
    config.isSemanticBoundary = true;
    config.textDirection = session.layout?.style.direction ?? TextDirection.ltr;
    final line = session.controller.activeLine;
    config.label = line == null
        ? ''
        : [line.text, if (line.translation != null) line.translation!]
            .join('\n');
  }
}
