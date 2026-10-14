import 'package:flutter/widgets.dart';
import '../controller/lyric_controller.dart';
import '../view/lyric_details.dart';
import '../view/lyric_view.dart';
import 'apple_music_lyric_style.dart';

/// Compatibility wrapper. New integrations can use LyricPresets.appleMusic.
class AppleMusicLyricView extends StatelessWidget {
  final LyricController controller;
  final AppleMusicLyricStyle style;
  final Object? viewId;
  final ValueChanged<LyricLineDetails>? onLineTap;
  final ValueChanged<LyricLineDetails?>? onSelectionChanged;
  final ValueChanged<bool>? onFollowChanged;

  const AppleMusicLyricView(
      {Key? key,
      required this.controller,
      this.style = const AppleMusicLyricStyle(),
      this.viewId,
      this.onLineTap,
      this.onSelectionChanged,
      this.onFollowChanged})
      : super(key: key);
  @override
  Widget build(BuildContext context) => LyricView(
      controller: controller,
      preset: style.toPreset(),
      viewId: viewId,
      onLineTap: onLineTap,
      onSelectionChanged: onSelectionChanged,
      onFollowChanged: onFollowChanged);
}
