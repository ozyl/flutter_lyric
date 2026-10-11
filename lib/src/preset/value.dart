import 'package:flutter/foundation.dart';

/// Value semantics without Object.hash/hashAll, which require Dart 2.14.
@immutable
abstract class PresetValue {
  const PresetValue();
  @protected
  List<Object?> get values;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PresetValue &&
          runtimeType == other.runtimeType &&
          listEquals(values, other.values);

  @override
  int get hashCode {
    var result = runtimeType.hashCode;
    for (final value in values) {
      result = 0x1fffffff & (result * 31 + value.hashCode);
    }
    return result;
  }
}
