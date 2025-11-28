import 'package:flutter/material.dart';
import 'package:flutter_lyric/core/lyric_controller.dart';
import 'package:flutter_lyric/core/lyric_style.dart';
import 'package:flutter_lyric/widgets/highlight_listenable_builder.dart';

class LyricSelectionContentBackground extends StatefulWidget {
  final LyricController controller;
  final LyricStyle style;
  final Color color;
  final double paddingHorizontal;
  final BorderRadius? borderRadius;
  const LyricSelectionContentBackground({
    Key? key,
    required this.controller,
    required this.style,
    this.color = Colors.white24,
    this.paddingHorizontal = 10,
    this.borderRadius,
  }) : super(key: key);

  @override
  State<LyricSelectionContentBackground> createState() =>
      _LyricSelectionContentBackgroundState();
}

class _LyricSelectionContentBackgroundState
    extends State<LyricSelectionContentBackground> {
  var _show = false;
  Function? cancelResumeSelectedLine;
  @override
  void initState() {
    super.initState();
    cancelResumeSelectedLine =
        controller.registerEvent(LyricEvent.resumeSelectedLine, (_) {
      setState(() {
        _show = true;
      });
    });
    controller.selectedIndexNotifier.addListener(onSelectedLineHeightChange);
  }

  void onSelectedLineHeightChange() {
    setState(() {
      _show = false;
    });
  }

  @override
  void dispose() {
    cancelResumeSelectedLine?.call();
    controller.selectedIndexNotifier.removeListener(onSelectedLineHeightChange);
    super.dispose();
  }

  LyricController get controller => widget.controller;
  get style => widget.style;
  get paddingHorizontal => widget.paddingHorizontal;
  get borderRadius => widget.borderRadius;
  @override
  Widget build(BuildContext context) {
    return SelectListenableBuilder(
      controller: controller,
      builder: (SelectionState state, Widget? child) {
        // 先计算 left 和 right
        double? leftValue;
        double? rightValue;

        switch (style.contentAlignment) {
          case CrossAxisAlignment.start:
            leftValue = style.contentPadding.left - paddingHorizontal;
            rightValue = null;
            break;
          case CrossAxisAlignment.center:
            leftValue = 0;
            rightValue = 0;
            break;
          case CrossAxisAlignment.end:
            leftValue = null;
            rightValue = style.contentPadding.right - paddingHorizontal;
            break;
          default:
            leftValue = null;
            rightValue = null;
        }
        return Positioned(
            top: controller.anchorAlignOffsetY + state.centerY,
            left: leftValue,
            right: rightValue,
            child: FractionalTranslation(
              translation: const Offset(0, -0.5),
              transformHitTests: true,
              child: Center(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  width: state.maxWidth + paddingHorizontal * 2,
                  height: state.lineHeight + style.lineGap,
                  decoration: BoxDecoration(
                    color: widget.color
                        .withValues(alpha: _show ? widget.color.a : 0),
                    borderRadius: borderRadius ?? BorderRadius.circular(10),
                  ),
                ),
              ),
            ));
      },
    );
  }
}
