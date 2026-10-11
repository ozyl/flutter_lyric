class Pair<T, U> {
  final T first;
  final U second;
  Pair({required this.first, required this.second});
  @override
  String toString() {
    return 'Pair(first: $first, second: $second)';
  }
}
