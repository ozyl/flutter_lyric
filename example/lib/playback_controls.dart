// @dart=3.8

import 'package:flutter/material.dart';
import 'demo_songs.dart';
import 'studio_theme.dart';

class PlaybackControls extends StatefulWidget {
  const PlaybackControls({
    super.key,
    required this.position,
    required this.duration,
    required this.playing,
    required this.onPlay,
    required this.onSeek,
    this.song = beWhatYouWannaBe,
    this.songs = demoSongs,
    this.onSongSelected,
    this.loading = false,
    this.error,
    this.onRetry,
  });
  final Duration position;
  final Duration duration;
  final bool playing;
  final bool loading;
  final String? error;
  final VoidCallback onPlay;
  final ValueChanged<Duration> onSeek;
  final VoidCallback? onRetry;
  final DemoSong song;
  final List<DemoSong> songs;
  final ValueChanged<DemoSong>? onSongSelected;
  @override
  State<PlaybackControls> createState() => _PlaybackControlsState();
}

class _PlaybackControlsState extends State<PlaybackControls> {
  double? _drag;
  String _time(Duration value) =>
      '${value.inMinutes.toString().padLeft(2, '0')}:${(value.inSeconds % 60).toString().padLeft(2, '0')}';
  @override
  Widget build(BuildContext context) {
    final max = widget.duration.inMilliseconds.toDouble();
    final ready = !widget.loading && widget.error == null && max > 0;
    final position = (_drag ?? widget.position.inMilliseconds.toDouble()).clamp(
      0.0,
      max > 0 ? max : 1.0,
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 600;
        final transport = Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              tooltip: '后退 10 秒',
              onPressed: ready
                  ? () => widget.onSeek(
                      Duration(
                        milliseconds: (position - 10000).clamp(0, max).round(),
                      ),
                    )
                  : null,
              icon: const Icon(Icons.replay_10_rounded, size: 22),
            ),
            IconButton.filled(
              tooltip: widget.playing ? '暂停' : '播放',
              onPressed: ready ? widget.onPlay : null,
              style: IconButton.styleFrom(
                backgroundColor: studioInk,
                foregroundColor: Colors.white,
              ),
              icon: widget.loading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Icon(
                      widget.playing
                          ? Icons.pause_rounded
                          : Icons.play_arrow_rounded,
                    ),
            ),
            IconButton(
              tooltip: '前进 10 秒',
              onPressed: ready
                  ? () => widget.onSeek(
                      Duration(
                        milliseconds: (position + 10000).clamp(0, max).round(),
                      ),
                    )
                  : null,
              icon: const Icon(Icons.forward_10_rounded, size: 22),
            ),
          ],
        );
        final track = Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: widget.song.coverAsset != null
                  ? Image.asset(
                      widget.song.coverAsset!,
                      width: 42,
                      height: 42,
                      fit: BoxFit.cover,
                    )
                  : Container(
                      width: 42,
                      height: 42,
                      color: studioInk,
                      child: const Icon(
                        Icons.music_note_rounded,
                        color: Colors.white,
                      ),
                    ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    widget.song.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    widget.song.artist,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 10, color: studioMuted),
                  ),
                ],
              ),
            ),
            if (widget.onSongSelected != null)
              const Icon(
                Icons.unfold_more_rounded,
                size: 18,
                color: studioMuted,
              ),
          ],
        );
        final songSelector = PopupMenuButton<DemoSong>(
          key: const ValueKey('song-selector'),
          tooltip: '切换歌曲',
          enabled: !widget.loading && widget.onSongSelected != null,
          initialValue: widget.song,
          onSelected: widget.onSongSelected,
          itemBuilder: (_) => [
            for (final song in widget.songs)
              PopupMenuItem(
                key: ValueKey('song-${song.id}'),
                value: song,
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(song.title),
                  subtitle: Text(song.artist),
                  trailing: song == widget.song
                      ? const Icon(Icons.check_rounded, color: studioAccent)
                      : null,
                ),
              ),
          ],
          child: track,
        );
        final progress = Row(
          children: [
            Text(
              _time(Duration(milliseconds: position.round())),
              style: const TextStyle(
                fontSize: 10,
                color: studioMuted,
                fontFamily: 'monospace',
              ),
            ),
            Expanded(
              child: SizedBox(
                height: 28,
                child: Slider(
                  key: const ValueKey('playback-slider'),
                  value: position,
                  max: max > 0 ? max : 1,
                  semanticFormatterCallback: (v) =>
                      _time(Duration(milliseconds: v.round())),
                  onChangeStart: ready
                      ? (v) => setState(() => _drag = v)
                      : null,
                  onChanged: ready ? (v) => setState(() => _drag = v) : null,
                  onChangeEnd: ready
                      ? (v) {
                          widget.onSeek(Duration(milliseconds: v.round()));
                          setState(() => _drag = null);
                        }
                      : null,
                ),
              ),
            ),
            Text(
              _time(widget.duration),
              style: const TextStyle(
                fontSize: 10,
                color: studioMuted,
                fontFamily: 'monospace',
              ),
            ),
          ],
        );
        return Container(
          padding: EdgeInsets.fromLTRB(wide ? 20 : 12, 12, wide ? 20 : 12, 8),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: .75),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: studioLine),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (constraints.maxWidth < 480) ...[
                songSelector,
                const SizedBox(height: 6),
                Center(child: transport),
              ] else
                Row(
                  children: [
                    Expanded(child: songSelector),
                    if (wide) const SizedBox(width: 16),
                    transport,
                  ],
                ),
              const SizedBox(height: 6),
              if (widget.error == null)
                progress
              else
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        widget.error!,
                        style: const TextStyle(
                          fontSize: 11,
                          color: Colors.deepOrange,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: widget.onRetry,
                      child: const Text('重试'),
                    ),
                  ],
                ),
            ],
          ),
        );
      },
    );
  }
}
