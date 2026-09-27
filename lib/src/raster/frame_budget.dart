import 'dart:async';
import 'dart:collection';

import 'package:flutter/scheduler.dart';

/// Lets at most [perFrame] tiles through to rasterization per frame, see
/// `VectorTileLayer.rasterTilesPerFrame`. Waiting tiles go through in the
/// order they asked, once the next frame is done. `0` lets everything
/// through at once.
class FrameBudget {
  final int perFrame;
  final void Function(void Function() callback) _afterNextFrame;
  final _waiting = Queue<Completer<void>>();
  int _used = 0;
  bool _resetScheduled = false;

  FrameBudget(this.perFrame,
      {void Function(void Function() callback)? afterNextFrame})
      : _afterNextFrame = afterNextFrame ?? _afterNextFlutterFrame;

  /// Completes when this tile may be rasterized. A tile that is cancelled
  /// after that hands its slot back with [giveBack].
  Future<void> acquire() {
    if (perFrame <= 0) {
      return Future.value();
    }
    _scheduleReset();
    if (_used < perFrame) {
      _used++;
      return Future.value();
    }
    final waiter = Completer<void>();
    _waiting.add(waiter);
    return waiter.future;
  }

  /// Returns a slot that [acquire] granted but that was not used, so that a
  /// cancelled tile does not hold back the next one.
  void giveBack() {
    if (perFrame <= 0) {
      return;
    }
    if (_waiting.isNotEmpty) {
      _waiting.removeFirst().complete();
    } else if (_used > 0) {
      _used--;
    }
  }

  void _scheduleReset() {
    if (_resetScheduled) {
      return;
    }
    _resetScheduled = true;
    _afterNextFrame(_reset);
  }

  void _reset() {
    _resetScheduled = false;
    _used = 0;
    while (_used < perFrame && _waiting.isNotEmpty) {
      _used++;
      _waiting.removeFirst().complete();
    }
    if (_used > 0) {
      _scheduleReset();
    }
  }

  static void _afterNextFlutterFrame(void Function() callback) {
    final scheduler = SchedulerBinding.instance;
    scheduler.addPostFrameCallback((_) => callback());
    // Without anything else to draw there might be no next frame, and the
    // waiting tiles would never be rasterized.
    scheduler.scheduleFrame();
  }
}
