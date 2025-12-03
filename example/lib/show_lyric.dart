import 'package:flutter/material.dart';
import 'package:flutter_lyric/core/lyric_controller.dart';
import 'package:flutter_lyric/core/lyric_style.dart';
import 'package:flutter_lyric/core/lyric_styles.dart';
import 'package:flutter_lyric/widgets/lyric_view.dart';
import 'package:flutter_lyric_example/edit_style.dart';
import 'package:flutter_lyric_example/mock.dart';

class ShowLyric extends StatefulWidget {
  const ShowLyric({
    super.key,
    required this.progress,
    this.beforeLyricBuilder,
    this.afterLyricBuilder,
    this.initStyle,
    this.initController,
  });
  final Duration progress;
  final LyricStyle? initStyle;
  final Function(LyricController)? initController;
  final List<Widget> Function(LyricController, LyricStyle)? beforeLyricBuilder;
  final List<Widget> Function(LyricController, LyricStyle)? afterLyricBuilder;

  @override
  State<ShowLyric> createState() => _ShowLyricState();
}

class _ShowLyricState extends State<ShowLyric> {
  LyricController lyricController = LyricController();
  final ValueNotifier<LyricStyle> _currentStyleNotifier = ValueNotifier(
    LyricStyles.default1,
  );

  @override
  void dispose() {
    lyricController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    _currentStyleNotifier.value = widget.initStyle ?? LyricStyles.default1;
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
        valueListenable: _currentStyleNotifier,
        builder: (context, style, child) {
          final isDark =
              MediaQuery.of(context).platformBrightness == Brightness.dark;
          // For performance, you should avoid creating a new style on every build. This is just a demo and not recommended.
          if (isDark) {
            style = style.copyWith(
              textStyle: style.textStyle.copyWith(
                color: Colors.black.withValues(alpha: 0.4),
              ),
              activeStyle: style.activeStyle.copyWith(
                color: Colors.black.withValues(alpha: .8),
              ),
              translationStyle: style.translationStyle.copyWith(
                color: Colors.black.withValues(alpha: 0.4),
              ),
              selectedColor: Colors.black.withValues(alpha: 0.9),
              selectedTranslationColor: Colors.black.withValues(alpha: 0.9),
              activeHighlightColor: style.activeHighlightColor?.withValues(
                alpha: 0.6,
              ),
              translationActiveColor: Colors.black.withValues(alpha: 0.6),
            );
          }
          return Stack(
            children: [
              ...?widget.beforeLyricBuilder?.call(lyricController, style),
              RepaintBoundary(
                child: LyricView(controller: lyricController, style: style),
              ),
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
                            valueListenable: _currentStyleNotifier,
                            builder: (context, value, child) {
                              return EditStyle(
                                style: value,
                                onStyleChanged: (style) {
                                  setState(() {
                                    _currentStyleNotifier.value = style;
                                  });
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
