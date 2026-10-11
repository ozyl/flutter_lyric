class LyricLineSwitchState {
  final double exitAnimationValue;
  final double enterAnimationValue;
  final int exitIndex;
  final int enterIndex;
  const LyricLineSwitchState(
      {this.exitAnimationValue = 1,
      this.enterAnimationValue = 1,
      this.exitIndex = -1,
      this.enterIndex = -1});
}
