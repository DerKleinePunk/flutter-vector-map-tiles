import 'package:test/test.dart';
import 'package:vector_map_tiles/src/raster/label_rotation.dart';

void main() {
  group('LabelRotationStepper', () {
    test('a step of 0 is off: always 0', () {
      final stepper = LabelRotationStepper(stepDegrees: 0);

      expect(stepper.update(0), 0);
      expect(stepper.update(180), 0);
      expect(stepper.update(-90), 0);
    });

    test('stays at 0 within half a step plus the hysteresis', () {
      final stepper = LabelRotationStepper(stepDegrees: 45);

      expect(stepper.update(20), 0);
      expect(stepper.update(32), 0);
      expect(stepper.update(-32), 0);
      expect(stepper.update(328), 0);
    });

    test('moves on past half a step plus the hysteresis', () {
      final stepper = LabelRotationStepper(stepDegrees: 45);

      expect(stepper.update(33), 45);
    });

    test('rounds to the nearest step, not only to the neighbour', () {
      final stepper = LabelRotationStepper(stepDegrees: 45);

      expect(stepper.update(180), 180);
      expect(stepper.update(-100), 270);
    });

    test('a heading wobbling around a boundary keeps its step', () {
      final stepper = LabelRotationStepper(stepDegrees: 45);
      stepper.update(40);
      expect(stepper.current, 45);

      for (final heading in [24.0, 21.0, 25.0, 13.0, 30.0, 23.0]) {
        expect(stepper.update(heading), 45,
            reason: 'the step changed at $heading');
      }
      expect(stepper.update(12), 0);
    });

    test('works across 0/360 in both directions', () {
      final stepper = LabelRotationStepper(stepDegrees: 45);

      expect(stepper.update(-40), 315);
      expect(stepper.update(345), 315);
      expect(stepper.update(-15), 315);
      expect(stepper.update(2), 0);
      expect(stepper.update(-25), 0);
      expect(stepper.update(725), 0);
    });

    test('a finer step with a smaller hysteresis', () {
      final stepper =
          LabelRotationStepper(stepDegrees: 30, hysteresisDegrees: 5);

      expect(stepper.update(19), 0);
      expect(stepper.update(21), 30);
    });

    test('a label is never more than half a step plus hysteresis off', () {
      final stepper = LabelRotationStepper(stepDegrees: 45);
      for (var heading = -720.0; heading <= 720.0; heading += 7.3) {
        final step = stepper.update(heading);
        final off = ((heading - step) % 360 + 360) % 360;
        final distance = off > 180 ? 360 - off : off;
        expect(distance, lessThanOrEqualTo(45 / 2 + 10),
            reason: 'heading $heading gave step $step');
      }
    });
  });

  group('labelRotationOf', () {
    test('reads the option and falls back to 0', () {
      expect(labelRotationOf({labelRotationOption: '135.0'}), 135.0);
      expect(labelRotationOf({}), 0.0);
      expect(labelRotationOf({labelRotationOption: 'x'}), 0.0);
    });
  });
}
