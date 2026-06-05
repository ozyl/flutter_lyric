import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_lyric/core/lyric_controller.dart';
import 'package:flutter_lyric/widgets/mixins/lyric_layout_mixin.dart';

class LyricLineSwitchState {
  double exitAnimationValue = 0.0;
  double enterAnimationValue = 0.0;
  int exitIndex = -1;
  int enterIndex = -1;

  LyricLineSwitchState({
    required this.exitAnimationValue,
    required this.enterAnimationValue,
    required this.exitIndex,
    required this.enterIndex,
  });
}

mixin LyricLineSwitchMixin<T extends StatefulWidget>
    on State<T>, LyricLayoutMixin<T>, TickerProviderStateMixin<T> {
  int _exitIndex = -1;
  int _enterIndex = -1;

  late final AnimationController _exitAnimationController;
  late final AnimationController _enterAnimationController;
  CurvedAnimation? _exitCurvedAnimation;
  CurvedAnimation? _enterCurvedAnimation;
  Curve? _cachedExitCurve;
  Curve? _cachedEnterCurve;

  @override
  void initState() {
    super.initState();
    controller.registerEvent(
        LyricEvent.playSwitchAnimation, onPlaySwitchAnimation);
    controller.registerEvent(LyricEvent.reset, _reset);
    _exitAnimationController = AnimationController(vsync: this);
    _enterAnimationController = AnimationController(vsync: this);
    _enterIndex = _exitIndex;
    controller.activeIndexNotifiter.addListener(onActiveIndexChange);
    _ensureSwitchCurvedAnimations();
  }

  void _ensureSwitchCurvedAnimations() {
    if (_exitCurvedAnimation != null &&
        _enterCurvedAnimation != null &&
        _cachedExitCurve == style.switchExitCurve &&
        _cachedEnterCurve == style.switchEnterCurve) {
      return;
    }
    _disposeSwitchCurvedAnimations();
    _cachedExitCurve = style.switchExitCurve;
    _cachedEnterCurve = style.switchEnterCurve;
    _exitCurvedAnimation = CurvedAnimation(
      parent: _exitAnimationController,
      curve: style.switchExitCurve,
    );
    _enterCurvedAnimation = CurvedAnimation(
      parent: _enterAnimationController,
      curve: style.switchEnterCurve,
    );
  }

  void _disposeSwitchCurvedAnimations() {
    _exitCurvedAnimation?.dispose();
    _enterCurvedAnimation?.dispose();
    _exitCurvedAnimation = null;
    _enterCurvedAnimation = null;
    _cachedExitCurve = null;
    _cachedEnterCurve = null;
  }

  void _reset(dynamic _) {
    if (!mounted) {
      return;
    }
    _exitIndex = -1;
    _enterIndex = -1;
    _exitAnimationController.value = 1.0;
    _enterAnimationController.value = 1.0;
  }

  void onPlaySwitchAnimation(dynamic _) {
    if (!mounted) {
      return;
    }
    _exitAnimationController.forward(from: 0);
    _enterAnimationController.forward(from: 0);
  }

  Widget buildLineSwitch(
      Widget Function(BuildContext context, LyricLineSwitchState state)
          builder) {
    _ensureSwitchCurvedAnimations();
    final exitAnimation = _exitCurvedAnimation!;
    final enterAnimation = _enterCurvedAnimation!;

    return AnimatedBuilder(
      animation: enterAnimation,
      builder: (context, child) {
        return AnimatedBuilder(
            animation: exitAnimation,
            builder: (context, child) {
              return builder(
                  context,
                  LyricLineSwitchState(
                    exitAnimationValue: exitAnimation.value,
                    enterAnimationValue: enterAnimation.value,
                    exitIndex: _exitIndex,
                    enterIndex: _enterIndex,
                  ));
            });
      },
    );
  }

  void onActiveIndexChange() {
    if (!mounted) {
      return;
    }
    _exitIndex = _enterIndex;
    final old = _enterIndex;
    _enterIndex = controller.activeIndexNotifiter.value;
    if (_enterIndex != _exitIndex) {
      _exitAnimationController.reset();
      _enterAnimationController.reset();
      _exitAnimationController.duration = style.switchExitDuration;
      _enterAnimationController.duration = style.switchEnterDuration;
      scheduleMicrotask(() {
        if (!mounted) {
          return;
        }
        // 如果是第一次切换（old == -1），只播放 enter 动画，不播放 exit 动画
        if (old != -1) {
          _exitAnimationController.forward(from: 0);
        } else {
          // 第一次切换时，将 exit 动画设置为完成状态，避免显示 exit 效果
          _exitAnimationController.value = 1.0;
        }
        _enterAnimationController.forward(from: 0);
      });
    }
  }

  @override
  void dispose() {
    controller.unregisterEvent(LyricEvent.reset, _reset);
    controller.unregisterEvent(
        LyricEvent.playSwitchAnimation, onPlaySwitchAnimation);
    controller.activeIndexNotifiter.removeListener(onActiveIndexChange);
    _exitAnimationController.stop();
    _enterAnimationController.stop();
    _disposeSwitchCurvedAnimations();
    _exitAnimationController.dispose();
    _enterAnimationController.dispose();
    super.dispose();
  }
}
