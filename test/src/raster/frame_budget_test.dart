import 'package:test/test.dart';
import 'package:vector_map_tiles/src/raster/frame_budget.dart';

void main() {
  late List<void Function()> frameCallbacks;

  FrameBudget budget(int perFrame) =>
      FrameBudget(perFrame, afterNextFrame: frameCallbacks.add);

  /// Runs the callbacks registered for the next frame, then lets the
  /// completed futures run.
  Future<void> frame() async {
    final callbacks = List.of(frameCallbacks);
    frameCallbacks.clear();
    for (final callback in callbacks) {
      callback();
    }
    await Future<void>.delayed(Duration.zero);
  }

  Future<List<int>> acquireAll(FrameBudget budget, int count) async {
    final granted = <int>[];
    for (var i = 0; i < count; i++) {
      budget.acquire().then((_) => granted.add(i));
    }
    await Future<void>.delayed(Duration.zero);
    return granted;
  }

  setUp(() => frameCallbacks = []);

  test('without a limit every tile goes through at once', () async {
    final b = budget(0);
    expect(await acquireAll(b, 5), [0, 1, 2, 3, 4]);
    expect(frameCallbacks, isEmpty, reason: 'no frame is forced');
  });

  test('a limit spreads the tiles over frames, in order', () async {
    final b = budget(2);
    final granted = await acquireAll(b, 5);
    expect(granted, [0, 1]);
    await frame();
    expect(granted, [0, 1, 2, 3]);
    await frame();
    expect(granted, [0, 1, 2, 3, 4]);
  });

  test('a returned slot goes to the next waiting tile', () async {
    final b = budget(1);
    final granted = await acquireAll(b, 3);
    expect(granted, [0]);
    b.giveBack();
    await Future<void>.delayed(Duration.zero);
    expect(granted, [0, 1]);
  });

  test('a returned slot without waiting tiles is free again', () async {
    final b = budget(1);
    expect(await acquireAll(b, 1), [0]);
    b.giveBack();
    expect(await acquireAll(b, 1), [0]);
  });

  test('Vorab wartet auch bei freiem Budget auf das Frame-Ende', () async {
    final b = budget(2);
    final granted = <String>[];
    b.acquire(lowPriority: true).then((_) => granted.add('low'));
    await Future<void>.delayed(Duration.zero);
    expect(granted, isEmpty);
    await frame();
    expect(granted, ['low']);
  });

  test('Vorab bekommt nur Plaetze, die kein sichtbarer wollte', () async {
    final b = budget(2);
    final granted = <String>[];
    for (var i = 0; i < 3; i++) {
      b.acquire().then((_) => granted.add('high$i'));
    }
    for (var i = 0; i < 2; i++) {
      b.acquire(lowPriority: true).then((_) => granted.add('low$i'));
    }
    await Future<void>.delayed(Duration.zero);
    expect(granted, ['high0', 'high1']);
    await frame();
    expect(granted, ['high0', 'high1', 'high2', 'low0']);
    await frame();
    expect(granted, ['high0', 'high1', 'high2', 'low0', 'low1']);
  });

  test('ohne Limit tropft Vorab mit einem je Frame durch', () async {
    final b = budget(0);
    final granted = <String>[];
    b.acquire().then((_) => granted.add('high'));
    b.acquire(lowPriority: true).then((_) => granted.add('low0'));
    b.acquire(lowPriority: true).then((_) => granted.add('low1'));
    await Future<void>.delayed(Duration.zero);
    expect(granted, ['high']);
    await frame();
    expect(granted, ['high', 'low0']);
    await frame();
    expect(granted, ['high', 'low0', 'low1']);
  });

  test('giveBack eines unbegrenzten Sichtbaren weckt kein Vorab', () async {
    final b = budget(0);
    final granted = <String>[];
    await b.acquire();
    b.acquire(lowPriority: true).then((_) => granted.add('low'));
    await Future<void>.delayed(Duration.zero);
    b.giveBack(); // der Sichtbare hielt keinen Platz
    await Future<void>.delayed(Duration.zero);
    expect(granted, isEmpty);
    await frame();
    expect(granted, ['low']);
  });

  test('stops asking for frames once nothing waits', () async {
    final b = budget(1);
    await acquireAll(b, 2);
    await frame();
    await frame();
    await frame();
    expect(frameCallbacks, isEmpty);
  });
}
