// @dart=3.8

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_lyric/flutter_lyric.dart';
import 'package:flutter_lyric_example/demo_presets.dart';
import 'package:flutter_lyric_example/edit_preset.dart';
import 'package:flutter_lyric_example/preset_export.dart';
import 'package:flutter_lyric_example/studio_state.dart';
import 'package:flutter_lyric_example/studio_theme.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<StudioState> mount(WidgetTester tester, Size size) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final state = StudioState();
    addTearDown(state.dispose);
    await tester.pumpWidget(
      MaterialApp(
        theme: studioTheme(),
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 360,
              child: ListenableBuilder(
                listenable: state,
                builder: (_, _) => EditPreset(state: state),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return state;
  }

  for (final size in [const Size(320, 568), const Size(1440, 1000)]) {
    testWidgets(
      'copy stays accessible across tabs and exports the current draft at $size',
      (tester) async {
        String? copied;
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          (call) async {
            if (call.method == 'Clipboard.setData') {
              copied = call.arguments['text'] as String;
            }
            return null;
          },
        );
        addTearDown(
          () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
            SystemChannels.platform,
            null,
          ),
        );
        final state = await mount(tester, size);
        state.update(state.preset.copyWith(lineSpacing: 37.5));
        await tester.pumpAndSettle();
        for (var tab = 0; tab < 4; tab++) {
          await tester.tap(find.byKey(ValueKey('inspector-tab-$tab')));
          await tester.pumpAndSettle();
          await tester.tap(find.byKey(const ValueKey('copy-preset')));
          await tester.pumpAndSettle();
          expect(copied, exportPreset(state.selected, state.preset));
          expect(copied, contains('lineSpacing: 37.5'));
        }
        for (final change in [
          state.undo,
          state.redo,
          state.reset,
          () => state.select(demoPresets[2]),
        ]) {
          change();
          await tester.pumpAndSettle();
          await tester.tap(find.byKey(const ValueKey('copy-preset')));
          await tester.pumpAndSettle();
          expect(copied, exportPreset(state.selected, state.preset));
        }
        await tester.tap(find.byTooltip('查看接入代码'));
        await tester.pumpAndSettle();
        expect(find.text('应用到你的项目'), findsOneWidget);
        expect(
          tester
              .widget<SelectableText>(find.byKey(const ValueKey('preset-code')))
              .data,
          copied,
        );
        await tester.tap(find.text('复制代码'));
        await tester.pumpAndSettle();
        expect(copied, exportPreset(state.selected, state.preset));
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }

  testWidgets('layout explains wrapping and reveals the public API field', (
    tester,
  ) async {
    final state = await mount(tester, const Size(400, 1000));
    await tester.tap(find.byKey(const ValueKey('inspector-tab-1')));
    await tester.pumpAndSettle();
    expect(find.text('随字号重新换行'), findsOneWidget);
    expect(find.text('保持换行位置'), findsOneWidget);
    await tester.tap(find.text('随字号重新换行'));
    await tester.pumpAndSettle();
    expect(state.preset.layoutMode, LyricLayoutMode.dualStyle);
    expect(find.textContaining('同一句可能从两行变成三行'), findsOneWidget);
    await tester.tap(find.text('保持换行位置'));
    await tester.pumpAndSettle();
    expect(state.preset.layoutMode, LyricLayoutMode.fixed);
    expect(find.textContaining('统一按当前句样式计算换行'), findsOneWidget);
    final api = find.byTooltip('LyricPreset.layoutMode');
    await tester.tap(api);
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('LyricPreset.layoutMode'), findsOneWidget);
  });

  testWidgets('countdown has three controls and supports history and export', (
    tester,
  ) async {
    final state = await mount(tester, const Size(400, 1000));
    expect(state.preset.countdown.enabled, isTrue);
    await tester.tap(find.byKey(const ValueKey('inspector-tab-2')));
    await tester.pumpAndSettle();
    for (final entry in {'小圆点数量': 5.0, '小圆点时长': 4.0, '小圆点呼吸时长': 1.5}.entries) {
      final slider = find.byKey(ValueKey('slider-${entry.key}'));
      await tester.scrollUntilVisible(slider, 300);
      tester.widget<Slider>(slider).onChanged!(entry.value);
      await tester.pumpAndSettle();
    }
    expect(state.preset.countdown.dotCount, 5);
    expect(state.preset.countdown.dotDuration, const Duration(seconds: 4));
    expect(
      state.preset.countdown.breathDuration,
      const Duration(milliseconds: 1500),
    );
    state.undo();
    await tester.pumpAndSettle();
    expect(
      state.preset.countdown.breathDuration,
      state.selected.preset.countdown.breathDuration,
    );
    state.redo();
    await tester.pumpAndSettle();
    final code = exportPreset(state.selected, state.preset);
    expect(code, contains('dotCount: 5'));
    expect(code, contains('dotDuration: Duration(milliseconds: 4000)'));
    expect(code, contains('breathDuration: Duration(milliseconds: 1500)'));
    for (final label in ['圆点计时模式', '最短空白时长', '仅最后几秒显示', '圆点直径', '圆点消退方向']) {
      expect(find.text(label), findsNothing);
    }
    await tester.scrollUntilVisible(find.text('显示圆点倒计时'), -200);
    await tester.tap(find.byKey(const ValueKey('toggle-显示圆点倒计时')));
    await tester.pumpAndSettle();
    expect(state.preset.countdown.enabled, isFalse);
    expect(find.text('小圆点数量'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('inherited active opacity matches the preview', (tester) async {
    final state = await mount(tester, const Size(400, 1000));
    state.select(demoPresets.singleWhere((v) => v.id == 'apple-music'));
    await tester.pumpAndSettle();
    final slider = find.byKey(const ValueKey('slider-当前句文字透明度'));
    await tester.scrollUntilVisible(slider, 200);
    expect(
      tester.widget<Slider>(slider).value,
      LyricPresets.appleMusic.textStyle.color!.a,
    );
  });

  testWidgets('float mode can be edited, retained, undone and exported', (
    tester,
  ) async {
    final state = await mount(tester, const Size(400, 1000));
    state.select(demoPresets.singleWhere((v) => v.id == 'apple-music'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('inspector-tab-2')));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('仅高亮文字'), 300);
    await tester.tap(find.text('仅高亮文字'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('当前句全部文字').last);
    await tester.pumpAndSettle();
    expect(state.preset.wordEffects.floatMode, LyricFloatMode.all);
    final amplitude = find.byKey(const ValueKey('slider-逐字悬浮'));
    await tester.scrollUntilVisible(amplitude, -200);
    tester.widget<Slider>(amplitude).onChanged!(2.5);
    await tester.pumpAndSettle();
    expect(state.preset.wordEffects.floatMode, LyricFloatMode.all);
    expect(
      exportPreset(state.selected, state.preset),
      contains('floatMode: LyricFloatMode.all'),
    );
    state.undo();
    state.undo();
    await tester.pumpAndSettle();
    expect(state.preset.wordEffects.floatMode, LyricFloatMode.highlighted);
    state.redo();
    await tester.pumpAndSettle();
    expect(state.preset.wordEffects.floatMode, LyricFloatMode.all);
    expect(tester.takeException(), isNull);
  });

  testWidgets('clipboard failure offers selectable code instead of success', (
    tester,
  ) async {
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          throw PlatformException(code: 'clipboard_unavailable');
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    await mount(tester, const Size(400, 1000));
    await tester.tap(find.byKey(const ValueKey('copy-preset')));
    await tester.pumpAndSettle();
    expect(find.textContaining('剪贴板不可用'), findsOneWidget);
    expect(find.textContaining('已复制 Dart 配置'), findsNothing);
    await tester.tap(find.text('查看代码'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('preset-code')), findsOneWidget);
  });
}
