import 'package:flutter/cupertino.dart';
import 'package:flutter_lyric/core/lyric_controller.dart';

class SelectionState {
  final double centerY;
  final int index;
  final double lineHeight;
  final Duration duration;
  final double maxWidth;
  final bool isSelecting;

  SelectionState({
    required this.centerY,
    required this.index,
    required this.duration,
    required this.lineHeight,
    required this.maxWidth,
    required this.isSelecting,
  });
}

class SelectListenableBuilder extends StatelessWidget {
  final LyricController controller;
  final Widget Function(SelectionState state, Widget? child) builder;
  final bool visibleWhenSelecting;

  const SelectListenableBuilder({
    Key? key,
    required this.controller,
    required this.builder,
    this.visibleWhenSelecting = true,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
        valueListenable: controller.selectedLineHeightNotifier,
        builder: (context, double lh, child) {
          return ValueListenableBuilder(
              valueListenable: controller.isSelectingNotifier,
              builder: (context, bool isSelecting, child) {
                if (visibleWhenSelecting && !isSelecting) {
                  return SizedBox.shrink();
                }
                return ValueListenableBuilder(
                  valueListenable: controller.anchorPositionNotifier,
                  builder: (context, double position, child) {
                    return ValueListenableBuilder(
                      valueListenable: controller.selectedIndexNotifier,
                      builder: (context, int index, child) {
                        return builder(
                            SelectionState(
                              isSelecting: isSelecting,
                              maxWidth: controller.selectedMaxWidth,
                              centerY: position,
                              index: index,
                              duration: controller.lyricNotifier.value
                                      ?.lines[index].start ??
                                  Duration.zero,
                              lineHeight: lh,
                            ),
                            child);
                      },
                      child: child,
                    );
                  },
                );
              });
        });
  }
}
