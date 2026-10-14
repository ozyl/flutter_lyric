import 'dart:ui' as ui;
import 'package:flutter/widgets.dart';
import '../controller/lyric_controller.dart';
import '../preset/lyric_effects.dart';
import '../preset/lyric_preset.dart';
import '../preset/lyric_preset_scope.dart';
import '../rendering/lyric_viewport.dart';
import '../rendering/edge_fade.dart';
import '../rendering/resolved_preset.dart';
import 'lyric_details.dart';
import 'lyric_view_session.dart';

/// A lyric viewport. Size it with normal Flutter layout widgets. A preset
/// switches appearance, interaction and presentation builders together.
class LyricView extends StatefulWidget {
  final LyricController controller;
  final LyricPreset? preset;
  final Object? viewId;
  final ValueChanged<LyricLineDetails>? onLineTap;
  final ValueChanged<LyricLineDetails?>? onSelectionChanged;
  final ValueChanged<bool>? onFollowChanged;

  const LyricView(
      {Key? key,
      required this.controller,
      this.preset,
      this.viewId,
      this.onLineTap,
      this.onSelectionChanged,
      this.onFollowChanged})
      : super(key: key);
  @override
  State<LyricView> createState() => _LyricViewState();
}

class _LyricViewState extends State<LyricView> with TickerProviderStateMixin {
  final EdgeFade _fade = EdgeFade();
  final Object _automaticId = Object();
  late LyricViewSession _session;
  @override
  void initState() {
    super.initState();
    _connect();
  }

  void _connect() {
    _session = LyricViewSession(
        controller: widget.controller,
        viewId: widget.viewId ?? _automaticId,
        vsync: this);
  }

  @override
  void didUpdateWidget(LyricView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.controller != oldWidget.controller ||
        widget.viewId != oldWidget.viewId) {
      _session.dispose();
      _connect();
    }
  }

  @override
  Widget build(BuildContext context) {
    final preset = widget.preset ?? LyricPresetScope.of(context);
    _session.onLineTap = widget.onLineTap;
    _session.onSelectionChanged = widget.onSelectionChanged;
    _session.onFollowChanged = widget.onFollowChanged;
    // ignore: deprecated_member_use
    _session.connection.enabled = TickerMode.of(context);
    final media = context.dependOnInheritedWidgetOfExactType<MediaQuery>();
    // Keep bare Flutter 2 hosts (without MediaQuery) at their native resolution.
    // ignore: deprecated_member_use
    final fallbackPixelRatio = ui.window.devicePixelRatio;
    _session.configure(
        ResolvedPreset(preset,
            ambient: DefaultTextStyle.of(context).style,
            direction: Directionality.of(context),
            // ignore: deprecated_member_use
            textScaleFactor: media?.data.textScaleFactor ?? 1,
            devicePixelRatio:
                media?.data.devicePixelRatio ?? fallbackPixelRatio,
            locale: Localizations.maybeLocaleOf(context)),
        // ignore: deprecated_member_use
        enabled: TickerMode.of(context),
        disableAnimations: media?.data.disableAnimations ?? false);
    final canScroll =
        preset.interactive && preset.displayMode == LyricDisplayMode.scrollable;
    Widget presentation(bool foreground) => ValueListenableBuilder<int>(
          valueListenable: _session.presentation,
          builder: (context, _, __) {
            if (_session.isEmpty) {
              return foreground
                  ? (preset.emptyBuilder?.call(context) ??
                      const SizedBox.shrink())
                  : const SizedBox.shrink();
            }
            final details = _session.selectionDetails;
            final builder = foreground
                ? preset.selectionForegroundBuilder
                : preset.selectionBackgroundBuilder;
            return details == null || builder == null
                ? const SizedBox.shrink()
                : builder(context, details);
          },
        );
    return Stack(fit: StackFit.expand, children: [
      Positioned.fill(child: IgnorePointer(child: presentation(false))),
      Positioned.fill(
          child: Listener(
        onPointerSignal: _session.pointerSignal,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapUp: canScroll || preset.interactive
              ? (details) => _session.tapAt(details.localPosition)
              : null,
          child: NotificationListener<ScrollNotification>(
            onNotification: _session.scrollNotification,
            child: LyricEdgeMask(
                fade: preset.edgeFade,
                cache: _fade,
                child: Scrollable(
                    controller: _session.scrollController,
                    physics: canScroll
                        ? const ClampingScrollPhysics()
                        : const NeverScrollableScrollPhysics(),
                    viewportBuilder: (context, offset) =>
                        LyricViewport(session: _session, offset: offset))),
          ),
        ),
      )),
      Positioned.fill(child: presentation(true)),
    ]);
  }

  @override
  void dispose() {
    _session.dispose();
    super.dispose();
  }
}
