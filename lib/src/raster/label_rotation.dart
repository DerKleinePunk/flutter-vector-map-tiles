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
/// half a step (plus [hysteresisDegrees]) of upright. The hysteresis keeps a
/// rotation that wobbles around a step boundary, as the heading of a car
/// does, from re-rendering the tiles again and again.
class LabelRotationStepper {
  /// The size of a step in degrees. `0` turns rotated labels off: [update]
  /// then always returns `0`.
  final double stepDegrees;

  /// How far the rotation has to move past the middle between two steps
  /// before the step changes.
  final double hysteresisDegrees;

  double _current = 0.0;

  LabelRotationStepper(
      {required this.stepDegrees, this.hysteresisDegrees = 10.0}) {
    assert(stepDegrees >= 0 && stepDegrees <= 180,
        'stepDegrees must be between 0 and 180');
    assert(hysteresisDegrees >= 0 && hysteresisDegrees < stepDegrees / 2 ||
        stepDegrees == 0);
  }

  /// The current step in degrees, in `[0, 360)`.
  double get current => _current;

  /// Returns the step for [rotationDegrees] (flutter_map's
  /// `MapCamera.rotation`, any value), in `[0, 360)`.
  double update(double rotationDegrees) {
    if (stepDegrees == 0) {
      return _current = 0.0;
    }
    final rotation = _normalize(rotationDegrees);
    final distance = _angleBetween(rotation, _current);
    if (distance > stepDegrees / 2 + hysteresisDegrees) {
      _current = _normalize((rotation / stepDegrees).round() * stepDegrees);
    }
    return _current;
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
