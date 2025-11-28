import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_lyric/core/lyric_controller.dart';
import 'package:flutter_lyric/core/lyric_style.dart';
import 'package:flutter_lyric/widgets/highlight_listenable_builder.dart';

class LyricSelectionProgress extends StatelessWidget {
  final LyricController controller;
  final LyricStyle style;
  final Function(SelectionState state) onPlay;
  const LyricSelectionProgress(
      {Key? key,
      required this.controller,
      required this.style,
      required this.onPlay})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return SelectListenableBuilder(
      controller: controller,
      builder: (
        SelectionState state,
        Widget? child,
      ) {
        return Positioned(
          top: state.centerY,
          right: 12,
          left: 12,
          child: FractionalTranslation(
            translation: Offset(0, -0.5),
            transformHitTests: true,
            child: SizedBox(
              height: 200,
              child: Stack(
                alignment: AlignmentDirectional.center,
                children: [
                  Positioned(
                    left: 20,
                    child: Text(
                      "${(state.duration.inMinutes).toString().padLeft(2, '0')}:${(state.duration.inSeconds % 60).toString().padLeft(2, '0')}",
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  Positioned(
                    left: 60,
                    right: 60,
                    child: Container(
                      height: 1,
                      color: Colors.white30,
                    ),
                  ),
                  Positioned(
                    right: 20,
                    child: GestureDetector(
                      onTap: () {
                        controller.stopSelection();
                        scheduleMicrotask(() {
                          onPlay(state);
                        });
                      },
                      child: Icon(
                        Icons.play_arrow,
                        size: 24,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class LyricSelectionProgress2 extends StatelessWidget {
  final LyricController controller;
  final LyricStyle style;
  final Function(SelectionState state) onPlay;
  const LyricSelectionProgress2(
      {Key? key,
      required this.controller,
      required this.style,
      required this.onPlay})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return SelectListenableBuilder(
      controller: controller,
      builder: (
        SelectionState state,
        Widget? child,
      ) {
        return Positioned(
          top: state.centerY,
          right: 12,
          left: 12,
          child: FractionalTranslation(
            translation: Offset(0, -0.5),
            transformHitTests: true,
            child: SizedBox(
              height: 200,
              child: Stack(
                alignment: AlignmentDirectional.center,
                children: [
                  Positioned(
                    right: 20,
                    child: GestureDetector(
                      onTap: () {
                        controller.stopSelection();
                        scheduleMicrotask(() {
                          onPlay(state);
                        });
                      },
                      child: DecoratedBox(
                        decoration: _SelectionProgressDecoration(),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                                  horizontal: 8.0, vertical: 2)
                              .copyWith(left: 2),
                          child: Row(
                            children: [
                              Icon(
                                Icons.play_arrow,
                                size: 14,
                                color: Colors.white60,
                              ),
                              Text(
                                "${(state.duration.inMinutes).toString().padLeft(2, '0')}:${(state.duration.inSeconds % 60).toString().padLeft(2, '0')}",
                                style: TextStyle(
                                    color: Colors.white60,
                                    fontSize: 12,
                                    height: 1),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _SelectionProgressDecoration extends Decoration {
  @override
  BoxPainter createBoxPainter([VoidCallback? onChanged]) {
    return _SelectionProgressBoxPainter(onChanged);
  }
}

class _SelectionProgressBoxPainter extends BoxPainter {
  _SelectionProgressBoxPainter(VoidCallback? onChanged) : super(onChanged);

  @override
  void paint(Canvas canvas, Offset offset, ImageConfiguration configuration) {
    final radius = 2.0;
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTWH(offset.dx, offset.dy, configuration.size!.width,
                configuration.size!.height),
            Radius.circular(radius)),
        Paint()..color = Colors.white10);

    final path = Path();
    //左侧绘制三角
    final triangleWidth = 8.0;
    path.moveTo(
        offset.dx - triangleWidth, offset.dy + configuration.size!.height / 2);
    path.lineTo(offset.dx, offset.dy + radius / 2);
    path.lineTo(offset.dx, offset.dy + configuration.size!.height - radius / 2);
    path.close();
    canvas.drawPath(path, Paint()..color = Colors.white10);
  }
}
