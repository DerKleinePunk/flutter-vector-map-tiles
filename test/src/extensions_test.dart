import 'dart:async';

import 'package:executor_lib/executor_lib.dart';
import 'package:test/test.dart';
import 'package:vector_map_tiles/src/extensions.dart';

void main() {
  Future<List<Object>> uncaughtWhile(Future<void> Function() body) async {
    final uncaught = <Object>[];
    await runZonedGuarded(() async {
      await body();
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }, (error, _) => uncaught.add(error));
    return uncaught;
  }

  test('an error before the await is not reported as unhandled', () async {
    final uncaught = await uncaughtWhile(() async {
      final future =
          Future<int>.error(CancellationException()).handledUntilAwaited();
      await Future<void>.delayed(const Duration(milliseconds: 5));
      await expectLater(future, throwsA(isA<CancellationException>()));
    });
    expect(uncaught, isEmpty);
  });

  test('a future that is never awaited stays quiet', () async {
    final uncaught = await uncaughtWhile(() async {
      Future<int>.error(CancellationException()).handledUntilAwaited();
    });
    expect(uncaught, isEmpty);
  });

  test('without it the error is unhandled', () async {
    final uncaught = await uncaughtWhile(() async {
      Future<int>.error(CancellationException());
    });
    expect(uncaught, [isA<CancellationException>()]);
  });
}
