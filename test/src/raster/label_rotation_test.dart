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
      expect(stepper.update(37), 0);
      expect(stepper.update(-37), 0);
      expect(stepper.update(323), 0);
    });

    test('moves on past half a step plus the hysteresis', () {
      final stepper = LabelRotationStepper(stepDegrees: 45);

      expect(stepper.update(38), 45);
    });

    test('rounds to the nearest step, not only to the neighbour', () {
      final stepper = LabelRotationStepper(stepDegrees: 45);

      expect(stepper.update(180), 180);
      expect(stepper.update(-100), 270);
    });

    test('a heading wobbling around a boundary keeps its step', () {
      final stepper = LabelRotationStepper(stepDegrees: 45);
      stepper.update(45);
      expect(stepper.current, 45);

      for (final heading in [24.0, 21.0, 25.0, 9.0, 30.0, 23.0]) {
        expect(stepper.update(heading), 45,
            reason: 'the step changed at $heading');
      }
      expect(stepper.update(7), 0);
    });

    test('works across 0/360 in both directions', () {
      final stepper = LabelRotationStepper(stepDegrees: 45);

      expect(stepper.update(-45), 315);
      expect(stepper.update(345), 315);
      expect(stepper.update(-10), 315);
      expect(stepper.update(7), 0);
      expect(stepper.update(-30), 0);
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
        expect(distance, lessThanOrEqualTo(45 / 2 + 15),
            reason: 'heading $heading gave step $step');
      }
    });
  });

  group('LabelRotationStepper with dwell', () {
    Duration s(double seconds) =>
        Duration(milliseconds: (seconds * 1000).round());

    test('a new step is taken only after it was wanted for the dwell', () {
      final stepper = LabelRotationStepper(stepDegrees: 45);

      expect(stepper.update(60, now: s(0)), 0);
      expect(stepper.update(62, now: s(1.9)), 0);
      expect(stepper.update(61, now: s(2.0)), 45);
    });

    test('swinging back before the dwell ends keeps the step', () {
      final stepper = LabelRotationStepper(stepDegrees: 45);
      stepper.update(270);

      // Heading as logged on the Pi: -102 / -123 back and forth.
      var t = 0.0;
      for (final heading in [-123.7, -102.0, -122.7, -102.3, -122.7, -101.0]) {
        expect(stepper.update(heading, now: s(t)), 270,
            reason: 'changed at $heading');
        t += 0.8;
      }
    });

    test('while waiting, a rotation more than 90° off is taken at once', () {
      final stepper = LabelRotationStepper(stepDegrees: 45);

      expect(stepper.update(60, now: s(0)), 0);
      expect(stepper.update(95, now: s(1.5)), 90);
    });

    test('the dwell starts over for a different target', () {
      final stepper = LabelRotationStepper(stepDegrees: 45);
      stepper.update(180);

      expect(stepper.update(130, now: s(0)), 180, reason: 'waits for 135');
      expect(stepper.update(230, now: s(1.5)), 180, reason: 'waits for 225');
      expect(stepper.update(230, now: s(3.0)), 180,
          reason: '225 is wanted since 1.5 s only');
      expect(stepper.update(230, now: s(3.5)), 225);
    });

    test('a turn of more than 90° is followed at once', () {
      final stepper = LabelRotationStepper(stepDegrees: 45);

      expect(stepper.update(180, now: s(0)), 180);
    });

    test('a pending step that is given up waits again next time', () {
      final stepper = LabelRotationStepper(stepDegrees: 45);

      expect(stepper.update(60, now: s(0)), 0);
      expect(stepper.update(10, now: s(1)), 0);
      expect(stepper.update(60, now: s(2.5)), 0,
          reason: 'the dwell starts again at 2.5 s');
      expect(stepper.update(60, now: s(4.5)), 45);
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
