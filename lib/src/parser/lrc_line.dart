class LrcLine {
  final List<Duration> durations;
  final String text;
  LrcLine({
    required this.durations,
    required this.text,
  });

  @override
  String toString() {
    return 'LrcLine(durations: $durations, text: $text)';
  }
}
