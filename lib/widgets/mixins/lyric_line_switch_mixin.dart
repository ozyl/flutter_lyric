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
  }

  _reset(_) {
    _exitIndex = -1;
    _enterIndex = -1;
    _exitAnimationController.value = 1.0;
    _enterAnimationController.value = 1.0;
  }

  void onPlaySwitchAnimation(_) {
    _exitAnimationController.forward(from: 0);
    _enterAnimationController.forward(from: 0);
  }

  buildLineSwitch(
      Widget Function(BuildContext context, LyricLineSwitchState state)
          builder) {
    final exitAnimation = CurvedAnimation(
      parent: _exitAnimationController,
      curve: style.switchExitCurve,
    );
    final enterAnimation = CurvedAnimation(
      parent: _enterAnimationController,
      curve: style.switchEnterCurve,
    );

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

  onActiveIndexChange() {
    _exitIndex = _enterIndex;
    final old = _enterIndex;
    _enterIndex = controller.activeIndexNotifiter.value;
    if (_enterIndex != _exitIndex) {
      _exitAnimationController.reset();
      _enterAnimationController.reset();
      _exitAnimationController.duration = style.switchExitDuration;
      _enterAnimationController.duration = style.switchEnterDuration;
      scheduleMicrotask(() {
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
    _exitAnimationController.dispose();
    _enterAnimationController.dispose();
    controller.activeIndexNotifiter.removeListener(onActiveIndexChange);
    controller.unregisterEvent(
        LyricEvent.playSwitchAnimation, onPlaySwitchAnimation);
    super.dispose();
  }
}
