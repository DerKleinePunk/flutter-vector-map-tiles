import 'dart:async';
import 'dart:collection';

import 'package:flutter/scheduler.dart';

/// Lets at most [perFrame] tiles through to rasterization per frame, see
/// `VectorTileLayer.rasterTilesPerFrame`. Waiting tiles go through in the
/// order they asked, once the next frame is done. `0` lets everything
/// through at once.
///
/// Low-priority tiles (prefetch, and tiles rendered again for a new label
/// rotation while their old image stays on screen) never take a slot away
/// from a regular tile: they are granted only slots that a frame left
/// unused, one frame later, and at most one per frame. On the Pi a tile
/// with labels costs tens of milliseconds to record; after a change of the
/// label rotation two of them per frame still made frames of 150 ms.
class FrameBudget {
  final int perFrame;
  final void Function(void Function() callback) _afterNextFrame;
  final _waiting = Queue<Completer<void>>();
  final _waitingLow = Queue<Completer<void>>();
  int _used = 0;
  int _usedLow = 0;
  bool _resetScheduled = false;

  FrameBudget(this.perFrame,
      {void Function(void Function() callback)? afterNextFrame})
      : _afterNextFrame = afterNextFrame ?? _afterNextFlutterFrame;

  /// Completes when this tile may be rasterized. A tile that is cancelled
  /// after that hands its slot back with [giveBack]. [lowPriority] tiles
  /// always wait for the end of the next frame and only get slots no
  /// regular tile wanted.
  Future<void> acquire({bool lowPriority = false}) {
    if (perFrame <= 0 && !lowPriority) {
      return Future.value();
    }
    _scheduleReset();
    if (!lowPriority && _used < perFrame) {
      _used++;
      return Future.value();
    }
    final waiter = Completer<void>();
    (lowPriority ? _waitingLow : _waiting).add(waiter);
    return waiter.future;
  }

  /// Returns a slot that [acquire] granted but that was not used, so that a
  /// cancelled tile does not hold back the next one. [lowPriority] must
  /// match the acquire call: an unlimited regular tile never held a slot.
  void giveBack({bool lowPriority = false}) {
    if (perFrame <= 0 && !lowPriority) {
      return;
    }
    if (_waiting.isNotEmpty) {
      _waiting.removeFirst().complete();
    } else if (_waitingLow.isNotEmpty && _usedLow < _lowPerFrame) {
      _usedLow++;
      _waitingLow.removeFirst().complete();
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

  /// One low-priority tile per frame when no [perFrame] limit is set.
  int get _capacity => perFrame > 0 ? perFrame : 1;

  static const _lowPerFrame = 1;

  void _reset() {
    _resetScheduled = false;
    _used = 0;
    _usedLow = 0;
    while (_used < perFrame && _waiting.isNotEmpty) {
      _used++;
      _waiting.removeFirst().complete();
    }
    while (_used < _capacity &&
        _usedLow < _lowPerFrame &&
        _waitingLow.isNotEmpty) {
      _used++;
      _usedLow++;
      _waitingLow.removeFirst().complete();
    }
    if (_used > 0 || _waitingLow.isNotEmpty) {
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
