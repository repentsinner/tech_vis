import 'package:tech_vis/tech_vis.dart';
import 'package:test/test.dart';

void main() {
  group('UnitSystem', () {
    test('metric and imperial are the two variants', () {
      expect(UnitSystem.values, hasLength(2));
      expect(UnitSystem.values, contains(UnitSystem.metric));
      expect(UnitSystem.values, contains(UnitSystem.imperial));
    });

    test('metric abbreviation is mm', () {
      expect(UnitSystem.metric.abbreviation, 'mm');
    });

    test('imperial abbreviation is in', () {
      expect(UnitSystem.imperial.abbreviation, 'in');
    });

    test('metric label is Metric (mm)', () {
      expect(UnitSystem.metric.label, 'Metric (mm)');
    });

    test('imperial label is Imperial (in)', () {
      expect(UnitSystem.imperial.label, 'Imperial (in)');
    });

    test('metric base unit is millimeters', () {
      expect(UnitSystem.metric.baseUnit, 'mm');
    });

    test('imperial base unit is inches', () {
      expect(UnitSystem.imperial.baseUnit, 'in');
    });

    group('conversion', () {
      test('metric to imperial converts mm to inches', () {
        final result = UnitSystem.metric.convertTo(25.4, UnitSystem.imperial);
        expect(result, closeTo(1.0, 1e-10));
      });

      test('imperial to metric converts inches to mm', () {
        final result = UnitSystem.imperial.convertTo(1.0, UnitSystem.metric);
        expect(result, closeTo(25.4, 1e-10));
      });

      test('same system returns identity', () {
        expect(UnitSystem.metric.convertTo(42.0, UnitSystem.metric), 42.0);
        expect(UnitSystem.imperial.convertTo(3.5, UnitSystem.imperial), 3.5);
      });

      test('zero converts to zero', () {
        expect(UnitSystem.metric.convertTo(0, UnitSystem.imperial), 0.0);
        expect(UnitSystem.imperial.convertTo(0, UnitSystem.metric), 0.0);
      });

      test('negative values convert correctly', () {
        final result = UnitSystem.metric.convertTo(-25.4, UnitSystem.imperial);
        expect(result, closeTo(-1.0, 1e-10));
      });
    });

    group('step sequences', () {
      test('metric coarse steps are standard metric increments', () {
        final steps = UnitSystem.metric.coarseSteps;
        expect(steps, isNotEmpty);
        // Should include common metric increments like 1, 5, 10, 50
        expect(steps, contains(1.0));
        expect(steps, contains(10.0));
      });

      test('imperial coarse steps are standard imperial increments', () {
        final steps = UnitSystem.imperial.coarseSteps;
        expect(steps, isNotEmpty);
        // Should include common imperial increments like 1/8, 1/4, 1/2, 1
        expect(steps, contains(0.25));
        expect(steps, contains(1.0));
      });

      test('metric fine steps are smaller than coarse', () {
        final fine = UnitSystem.metric.fineSteps;
        final coarse = UnitSystem.metric.coarseSteps;
        expect(fine, isNotEmpty);
        expect(fine.first, lessThan(coarse.first));
      });

      test('imperial fine steps are smaller than coarse', () {
        final fine = UnitSystem.imperial.fineSteps;
        final coarse = UnitSystem.imperial.coarseSteps;
        expect(fine, isNotEmpty);
        expect(fine.first, lessThan(coarse.first));
      });

      test('steps are sorted ascending', () {
        for (final system in UnitSystem.values) {
          final coarse = system.coarseSteps;
          for (var i = 1; i < coarse.length; i++) {
            expect(
              coarse[i],
              greaterThan(coarse[i - 1]),
              reason: '$system coarse steps not sorted at index $i',
            );
          }
          final fine = system.fineSteps;
          for (var i = 1; i < fine.length; i++) {
            expect(
              fine[i],
              greaterThan(fine[i - 1]),
              reason: '$system fine steps not sorted at index $i',
            );
          }
        }
      });

      test('all step values are positive', () {
        for (final system in UnitSystem.values) {
          for (final step in system.coarseSteps) {
            expect(step, greaterThan(0), reason: '$system coarse step <= 0');
          }
          for (final step in system.fineSteps) {
            expect(step, greaterThan(0), reason: '$system fine step <= 0');
          }
        }
      });
    });

    group('decimal places', () {
      test('metric uses 3 decimal places', () {
        expect(UnitSystem.metric.decimalPlaces, 3);
      });

      test('imperial uses 4 decimal places', () {
        expect(UnitSystem.imperial.decimalPlaces, 4);
      });
    });
  });
}
