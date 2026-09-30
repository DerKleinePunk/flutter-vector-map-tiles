import 'dart:math';

/// The key under which the label rotation of a raster tile travels in
/// flutter_map's `TileLayer.additionalOptions`.
///
/// A change of the value makes the `TileLayer` reload its visible tiles
/// (`TileImageManager.reloadImages`), and each tile keeps showing its old
/// image until the new one has loaded. The tile provider and loader read the
/// value from the layer they are handed.
const labelRotationOption = 'vmtLabelRotation';

/// The label rotation in degrees stored in [options] under
/// [labelRotationOption], `0` if there is none.
double labelRotationOf(Map<String, String> options) =>
    double.tryParse(options[labelRotationOption] ?? '') ?? 0.0;

/// Rounds the map rotation to steps for rendering labels into raster tiles.
///
/// Raster tiles are rendered once and rotated with the map, so a label that
/// is upright at a rotation of 0° stands on its head at 180°. Rendering the
/// tiles for the rotation rounded to [stepDegrees] keeps every label within
/// half a step (plus [hysteresisDegrees]) of upright.
///
/// Every change of the step renders all visible tiles again, so changes are
/// kept rare: the rotation has to move [hysteresisDegrees] past the middle
/// between two steps, and stay there for [dwell], before the step follows.
/// On a winding road the heading swings back and forth across a boundary;
/// measured on the Pi, a hysteresis of 10° alone still changed the step 46
/// times in two minutes. A rotation more than 90° off the current step (a
/// turn) changes it at once.
class LabelRotationStepper {
  /// The size of a step in degrees. `0` turns rotated labels off: [update]
  /// then always returns `0`.
  final double stepDegrees;

  /// How far the rotation has to move past the middle between two steps
  /// before the step changes.
  final double hysteresisDegrees;

  /// How long a new step has to be wanted before it is taken.
  final Duration dwell;

  double _current = 0.0;
  double? _pending;
  Duration? _pendingSince;

  LabelRotationStepper(
      {required this.stepDegrees,
      this.hysteresisDegrees = 15.0,
      this.dwell = const Duration(seconds: 2)}) {
    assert(stepDegrees >= 0 && stepDegrees <= 180,
        'stepDegrees must be between 0 and 180');
    assert(hysteresisDegrees >= 0 && hysteresisDegrees < stepDegrees / 2 ||
        stepDegrees == 0);
  }

  /// The current step in degrees, in `[0, 360)`.
  double get current => _current;

  /// Whether a new step waits for its [dwell]. The caller has to call
  /// [update] again once it has passed, also when the map does not move.
  bool get isPending => _pending != null;

  /// Returns the step for [rotationDegrees] (flutter_map's
  /// `MapCamera.rotation`, any value), in `[0, 360)`.
  ///
  /// [now] is a monotonic time, for [dwell]. Without it a new step is taken
  /// at once.
  double update(double rotationDegrees, {Duration? now}) {
    if (stepDegrees == 0) {
      return _current = 0.0;
    }
    final rotation = _normalize(rotationDegrees);
    final distance = _angleBetween(rotation, _current);
    if (distance <= stepDegrees / 2 + hysteresisDegrees) {
      _pending = null;
      return _current;
    }
    final target = _normalize((rotation / stepDegrees).round() * stepDegrees);
    if (now == null || distance > 90) {
      return _take(target);
    }
    final since = _pendingSince;
    if (_pending != target || since == null) {
      _pending = target;
      _pendingSince = now;
      return _current;
    }
    return now - since >= dwell ? _take(target) : _current;
  }

  double _take(double step) {
    _pending = null;
    _pendingSince = null;
    return _current = step;
  }

  static double _normalize(double degrees) {
    final value = degrees % 360.0;
    return value < 0 ? value + 360.0 : value;
  }

  static double _angleBetween(double a, double b) {
    final difference = (a - b).abs() % 360.0;
    return min(difference, 360.0 - difference);
  }
}
