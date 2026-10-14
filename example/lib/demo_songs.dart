// @dart=3.8

import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_lyric/flutter_lyric.dart';

import 'mock.dart';

class DemoSong {
  const DemoSong({
    required this.id,
    required this.title,
    required this.artist,
    required this.audioAsset,
    required this.loadLyrics,
    this.coverAsset,
  });

  final String id;
  final String title;
  final String artist;
  final String audioAsset;
  final String? coverAsset;
  final Future<LyricDocument> Function() loadLyrics;
}

const beWhatYouWannaBe = DemoSong(
  id: 'be-what-you-wanna-be',
  title: 'Be What You Wanna Be',
  artist: 'Darin',
  audioAsset: 'assets/music.mp3',
  coverAsset: 'assets/cover.webp',
  loadLyrics: _loadOriginalLyrics,
);

const stay = DemoSong(
  id: 'stay',
  title: 'STAY (Explicit)',
  artist: 'The Kid LAROI / Justin Bieber',
  audioAsset: 'assets/stay.mp3',
  loadLyrics: _loadStayLyrics,
);

const demoSongs = [beWhatYouWannaBe, stay];

Future<LyricDocument> _loadOriginalLyrics() async =>
    LyricDocument.parse(qrc, translation: tlrc);

Future<LyricDocument> _loadStayLyrics() => loadBundledLyrics('assets/stay');

/// Loads the QRC, translation and downloader's `.meta.json` with one prefix.
/// `startTs` is an optional non-negative millisecond value on the lyric timeline.
Future<LyricDocument> loadBundledLyrics(
  String assetPrefix, {
  AssetBundle? bundle,
}) async {
  final assets = bundle ?? rootBundle;
  final lyrics = await Future.wait([
    assets.loadString('$assetPrefix.qrc'),
    assets.loadString('$assetPrefix.trans.lrc'),
    assets.loadString('$assetPrefix.meta.json'),
  ]);
  final metadata = jsonDecode(lyrics[2]);
  if (metadata is! Map<String, dynamic>) {
    throw FormatException('$assetPrefix.meta.json must contain a JSON object.');
  }
  final startTs = metadata['startTs'];
  if (startTs != null && (startTs is! int || startTs < 0)) {
    throw FormatException(
      '$assetPrefix.meta.json startTs must be a non-negative integer or null.',
    );
  }
  return LyricDocument.parse(
    lyrics[0],
    translation: lyrics[1],
    vocalStart: startTs is int ? Duration(milliseconds: startTs) : null,
  );
}
