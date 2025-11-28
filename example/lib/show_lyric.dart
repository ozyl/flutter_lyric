import 'package:flutter/material.dart';
import 'package:flutter_lyric/core/lyric_controller.dart';
import 'package:flutter_lyric/core/lyric_style.dart';
import 'package:flutter_lyric/widgets/lyric_view.dart';
import 'package:flutter_lyric_example/edit_style.dart';
import 'package:flutter_lyric_example/mock.dart';

class ShowLyric extends StatefulWidget {
  const ShowLyric({
    super.key,
    required this.progress,
    this.beforeLyricBuilder,
    this.afterLyricBuilder,
    this.initController,
  });
  final Duration progress;
  final Function(LyricController)? initController;
  final List<Widget> Function(LyricController, LyricStyle)? beforeLyricBuilder;
  final List<Widget> Function(LyricController, LyricStyle)? afterLyricBuilder;

  @override
  State<ShowLyric> createState() => _ShowLyricState();
}

class _ShowLyricState extends State<ShowLyric> {
  LyricController lyricController = LyricController();

  @override
  void dispose() {
    lyricController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    lyricController.loadLyric(qrc, translationLyric: tlrc);
    lyricController.setProgress(widget.progress);
    widget.initController?.call(lyricController);
    super.initState();
  }

  @override
  void didUpdateWidget(covariant ShowLyric oldWidget) {
    if (oldWidget.progress != widget.progress) {
      lyricController.setProgress(widget.progress);
    }
    super.didUpdateWidget(oldWidget);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(border: Border.all(color: Colors.white10)),
      child: ValueListenableBuilder(
        valueListenable: lyricController.styleNotifier,
        builder: (context, style, child) {
          return Stack(
            children: [
              ...?widget.beforeLyricBuilder?.call(lyricController, style),
              RepaintBoundary(child: LyricView(controller: lyricController)),
              ...?widget.afterLyricBuilder?.call(lyricController, style),
              Positioned(
                right: 20,
                top: 20,
                child: Row(
                  children: [
                    GestureDetector(
                      child: Icon(Icons.settings, color: Colors.white),
                      onTap: () {
                        showDialog(
                          context: context,
                          builder: (context) => ValueListenableBuilder(
                            valueListenable: lyricController.styleNotifier,
                            builder: (context, value, child) {
                              return EditStyle(
                                style: value,
                                onStyleChanged: (style) {
                                  lyricController.setStyle(style);
                                },
                              );
                            },
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
