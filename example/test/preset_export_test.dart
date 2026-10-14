// @dart=3.8

import 'package:flutter/material.dart';
import 'package:flutter_lyric/flutter_lyric.dart';
import 'package:flutter_lyric_example/demo_line_transitions.dart';
import 'package:flutter_lyric_example/demo_presets.dart';
import 'package:flutter_lyric_example/preset_export.dart';
import 'package:flutter_lyric_example/scroll_tuning.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('float mode is included in exported word effects', () {
    final demo = demoPresets.singleWhere((v) => v.id == 'apple-music');
    final preset = demo.preset.copyWith(
      wordEffects: const LyricWordEffects(
        floatAmplitude: 1.4,
        floatMode: LyricFloatMode.all,
        simulateTiming: true,
      ),
    );
    expect(
      exportPreset(demo, preset),
      contains('floatMode: LyricFloatMode.all'),
    );
  });

  test('countdown exports all Canvas dot settings', () {
    final demo = demoPresets.first;
    final preset = demo.preset.copyWith(
      countdown: const LyricCountdown(
        dotDuration: Duration(seconds: 4),
        dotCount: 5,
        direction: LyricCountdownDirection.rightToLeft,
        breathDuration: Duration(milliseconds: 1250),
        dotSize: 9,
        dotSpacing: 7,
        color: Color(0xFF112233),
        inactiveColor: Color(0x33445566),
        height: 30,
        spacing: 18,
      ),
    );
    final code = exportPreset(demo, preset);
    for (final field in [
      'countdown: LyricCountdown(',
      'enabled: true',
      'dotDuration: Duration(milliseconds: 4000)',
      'dotCount: 5',
      'direction: LyricCountdownDirection.rightToLeft',
      'breathDuration: Duration(milliseconds: 1250)',
      'dotSize: 9.0',
      'dotSpacing: 7.0',
      'color: const Color(0xFF112233)',
      'inactiveColor: const Color(0x33445566)',
      'height: 30.0',
      'spacing: 18.0',
    ]) {
      expect(code, contains(field));
    }
    expect(
      exportPreset(
        demo,
        preset.copyWith(countdown: preset.countdown.copyWith(enabled: false)),
      ),
      contains('enabled: false'),
    );
  });

  test('every gallery style exports using public APIs only', () {
    for (final demo in demoPresets) {
      expect(demo.preset.countdown.enabled, isTrue);
      expect(demo.preset.countdown.color, isNotNull);
      final code = exportPreset(demo, demo.preset);
      expect(
        code,
        contains("import 'package:flutter_lyric/flutter_lyric.dart';"),
      );
      expect(code, contains('final lyricPreset = LyricPresets.'));
      expect(code, contains('preset: lyricPreset'));
      expect(code, isNot(contains('flutter_lyric_example')));
      expect(code, isNot(contains('Instance of')));
    }
    expect(
      exportPreset(
        demoPresets.singleWhere((v) => v.id == 'moss'),
        LyricPresets.moss,
      ),
      contains('final lyricPreset = LyricPresets.moss;'),
    );
    expect(
      exportPreset(
        demoPresets.singleWhere((v) => v.id == 'moss'),
        LyricPresets.moss.copyWith(lineSpacing: 40),
      ),
      isNot(contains("import 'package:flutter/material.dart';")),
    );
    final terminal = demoPresets.singleWhere((v) => v.id == 'terminal');
    expect(
      exportPreset(terminal, terminal.preset),
      contains('fontFamily: "monospace"'),
    );
    expect(
      exportPreset(terminal, terminal.preset),
      contains('LyricLineTransitions.step.copyWith('),
    );
  });

  test(
    'edits retain precision, nullable clears and distance-based scrolling',
    () {
      final demo = demoPresets.singleWhere((v) => v.id == 'moss');
      final color = const Color(0xFFF49AFF).withValues(alpha: .4137);
      final preset = demo.preset.copyWith(
        activeTextStyle: demo.preset.activeTextStyle.copyWith(
          color: color,
          fontSize: 37.125,
        ),
        clearResumeDelay: true,
        clearSelectedTextColor: true,
        activeAnchor: const LyricAnchor.pixels(
          123.5,
          target: LyricAnchorTarget.translationText,
        ),
        scrollAnimation: tuneScroll(
          LyricScrollAnimation.byDistance(
            durations: {
              50: const Duration(milliseconds: 200),
              200: const Duration(milliseconds: 800),
            },
          ),
          milliseconds: 300,
          curve: Curves.easeOutBack,
        ),
      );
      final code = exportPreset(demo, preset);
      expect(code, contains('fontSize: 37.125'));
      expect(code, contains('alpha: 0.4137'));
      expect(code, contains('clearResumeDelay: true'));
      expect(code, contains('clearSelectedTextColor: true'));
      expect(
        code,
        contains(
          'LyricAnchor.pixels(123.5, target: LyricAnchorTarget.translationText)',
        ),
      );
      expect(code, contains('50.0: Duration(milliseconds: 300)'));
      expect(code, contains('200.0: Duration(milliseconds: 1200)'));
      expect(code, contains('curve: Curves.easeOutBack'));
    },
  );

  test('every transition exports after retiming in both display modes', () {
    for (final mode in LyricDisplayMode.values) {
      for (final item in demoLineTransitions) {
        final preset = demoPresets.first.preset.copyWith(
          displayMode: mode,
          lineTransition: item
              .forMode(mode)
              .copyWith(
                enterDuration: const Duration(milliseconds: 321),
                exitDuration: const Duration(milliseconds: 456),
              ),
        );
        final code = exportPreset(demoPresets.first, preset);
        expect(code, contains('LyricLineTransitions.'), reason: item.name);
        if (preset.lineTransition.enabled) {
          expect(code, contains('enterDuration: Duration(milliseconds: 321)'));
          expect(code, contains('exitDuration: Duration(milliseconds: 456)'));
        }
      }
    }
  });

  test('unsupported application code is never silently dropped', () {
    final demo = demoPresets.first;
    expect(
      () => exportPreset(
        demo,
        demo.preset.copyWith(emptyBuilder: (_) => const SizedBox()),
      ),
      throwsUnsupportedError,
    );
    expect(
      () => exportPreset(
        demo,
        demo.preset.copyWith(
          scrollAnimation: LyricScrollAnimation.custom(
            (_) => const LyricAnimation(duration: Duration.zero),
          ),
        ),
      ),
      throwsUnsupportedError,
    );
    expect(
      () => exportPreset(
        demo,
        demo.preset.copyWith(
          textStyle: demo.preset.textStyle.copyWith(
            decoration: TextDecoration.underline,
          ),
        ),
      ),
      throwsUnsupportedError,
    );
  });
}
