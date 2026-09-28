import 'dart:async';

extension ListExtension<T> on List<T> {
  List<T> sorted([int Function(T a, T b)? compare]) {
    final copy = toList();
    copy.sort(compare);
    return copy;
  }
}

extension IterableExtension<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}

extension FutureExtension<T> on Future<T> {
  /// For a future that is started now but awaited only later: without a
  /// listener, an error in between - typically a CancellationException of
  /// a discarded tile - surfaces as an unhandled "Cancelled" in the zone.
  /// A later await still sees the error.
  Future<T> handledUntilAwaited() {
    unawaited(then((_) {}, onError: (_) {}));
    return this;
  }
}
