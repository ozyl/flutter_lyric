// @dart=3.8

import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_lyric_example/demo_songs.dart';
import 'package:flutter_test/flutter_test.dart';

class _LyricsBundle extends CachingAssetBundle {
  _LyricsBundle(String metadata)
    : files = {
        'assets/song.qrc':
            '[ti:Example]\n[0,59997]Credit(0,59997)\n'
            '[59997,1667]Vocal(59997,1667)',
        'assets/song.trans.lrc': '[00:59.99]Translation',
        'assets/song.meta.json': metadata,
      };

  final Map<String, String> files;

  @override
  Future<ByteData> load(String key) async =>
      ByteData.sublistView(Uint8List.fromList(utf8.encode(files[key]!)));
}

void main() {
  test(
    'bundled loader reads provider metadata without rewriting QRC',
    () async {
      final document = await loadBundledLyrics(
        'assets/song',
        bundle: _LyricsBundle('{"startTs":59997}'),
      );
      expect(document.vocalStart, const Duration(milliseconds: 59997));
      expect(document.title, 'Example');
      expect(document.lines.first.text, 'Credit');
      expect(document.lines.first.end, document.vocalStart);
      expect(document.lines.last.translation, 'Translation');
      expect(document.lines.last.words!.single.start, document.vocalStart);
    },
  );

  test('missing and null startTs retain normal gap detection', () async {
    for (final metadata in ['{}', '{"startTs":null}']) {
      final document = await loadBundledLyrics(
        'assets/song',
        bundle: _LyricsBundle(metadata),
      );
      expect(document.vocalStart, isNull);
    }
    final document = await loadBundledLyrics(
      'assets/song',
      bundle: _LyricsBundle('{"startTs":0}'),
    );
    expect(document.vocalStart, Duration.zero);
  });

  test(
    'malformed metadata fails explicitly instead of guessing vocal timing',
    () async {
      for (final metadata in [
        'invalid JSON',
        '[]',
        'null',
        '{"startTs":-1}',
        '{"startTs":"59997"}',
        '{"startTs":59997.5}',
        '{"startTs":true}',
      ]) {
        await expectLater(
          loadBundledLyrics('assets/song', bundle: _LyricsBundle(metadata)),
          throwsFormatException,
        );
      }
    },
  );
}
