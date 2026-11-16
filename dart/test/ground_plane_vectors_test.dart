import 'dart:convert';
import 'dart:math' as math;

import 'package:tech_vis/tech_vis.dart';
import 'package:test/test.dart';

import 'support/fake_text_resolver.dart';
import 'support/vectors.dart';

final _fixture = vectorFixture('ground_plane.json');

double? _optionalNumber(Object? json) => json == null ? null : jsonNumber(json);

GroundPatch _patch(Json json) => switch (json['shape']) {
  'rectangle' => RectangularGroundPatch(
    halfExtentU: jsonNumber(json['halfExtentU']),
    halfExtentV: jsonNumber(json['halfExtentV']),
  ),
  'circle' => CircularGroundPatch(radius: jsonNumber(json['radius'])),
  final shape => throw ArgumentError.value(shape, 'shape'),
};

GroundGridStyle _style(Json json) => GroundGridStyle(
  minLineSpacingPixels: jsonNumber(json['minLineSpacingPixels']),
  stepMargin: jsonNumber(json['stepMargin']),
  maxLinesPerAxis: json['maxLinesPerAxis'] as int,
  fadeSegments: json['fadeSegments'] as int,
  minorLineWidth: jsonNumber(json['minorLineWidth']),
  majorLineWidth: jsonNumber(json['majorLineWidth']),
  labelPixelSize: jsonNumber(json['labelPixelSize']),
);

/// Rebuilds a recorded grid through the public factory.
GroundGrid _build(Json input) {
  final conventionJson = input['convention'] as Json;
  final convention = CoordinateConvention(
    up: SpatialAxis.values.byName(conventionJson['up'] as String),
    handedness: Handedness.values.byName(
      conventionJson['handedness'] as String,
    ),
  );
  final camera = input['camera'] as Json;
  final target = jsonVector3(camera['target']);
  return GroundPlaneFactory.create(
    convention: convention,
    patch: _patch(input['patch'] as Json),
    format: DisplayFormat.values.byName(input['format'] as String),
    worldUnits: UnitSystem.values.byName(input['worldUnits'] as String),
    camera: CameraBasis.lookAt(
      position: jsonVector3(camera['position']),
      target: target,
      convention: convention,
    ),
    target: target,
    verticalFovRadians:
        jsonNumber(camera['verticalFovDegrees']) * math.pi / 180,
    viewportHeight: jsonNumber(camera['viewportHeight']),
    resolveText: fakeTextResolver,
    minorKey: 'minor',
    majorKey: 'major',
    labelKey: 'label',
    origin: jsonVector3(input['origin']),
    previousMinorStep: _optionalNumber(input['previousMinorStep']),
    style: _style(input['style'] as Json),
  );
}

void _expectPrimitive(Primitive actual, Json expected, String reason) {
  expect(actual.key, expected['key'], reason: '$reason key');
  expect(
    actual.opacity,
    closeTo(jsonNumber(expected['opacity']), vectorTolerance),
    reason: '$reason opacity',
  );
  switch ((actual, expected['type'])) {
    case (final LinePrimitive line, 'line'):
      expectNumbers(line.start.storage, expected['start'], '$reason start');
      expectNumbers(line.end.storage, expected['end'], '$reason end');
      expect(
        line.widthPixels,
        closeTo(jsonNumber(expected['widthPixels']), vectorTolerance),
        reason: '$reason width',
      );
    case (final BillboardPrimitive label, 'billboard'):
      expectNumbers(label.anchor.storage, expected['anchor'], '$reason anchor');
      expectNumbers(
        label.alignment.storage,
        expected['alignment'],
        '$reason alignment',
      );
      final request = expected['textRequest'] as Json;
      expect(
        label.content.value,
        TextRequest(
          text: request['text'] as String,
          heightPixels: jsonNumber(request['heightPixels']),
        ),
        reason: '$reason text',
      );
    default:
      fail('$reason: expected a ${expected['type']}, got $actual');
  }
}

void main() {
  final skip = skipUnlessPresent(_fixture);

  group('ground plane golden vectors', () {
    late Json fixture;

    setUpAll(() {
      fixture = jsonDecode(_fixture.readAsStringSync()) as Json;
    });

    test('are generated from the current style version', () {
      expect(fixture['styleVersion'], StyleTokens.styleVersion);
    });

    test('GroundPlaneFactory.minorStep', () {
      final cases = jsonList(fixture['GroundPlaneFactory.minorStep']);
      expect(cases, isNotEmpty);
      for (final c in cases) {
        final input = c['input'] as Json;
        expect(
          GroundPlaneFactory.minorStep(
            format: DisplayFormat.values.byName(input['format'] as String),
            minimumSpacing: jsonNumber(input['minimumSpacing']),
            previousStep: _optionalNumber(input['previousStep']),
            margin: jsonNumber(input['margin']),
          ),
          closeTo(jsonNumber((c['output'] as Json)['step']), vectorTolerance),
          reason: c['name'] as String,
        );
      }
    });

    test('GroundPlaneFactory.create', () {
      final cases = jsonList(fixture['GroundPlaneFactory.create']);
      expect({
        for (final c in cases)
          ((c['input'] as Json)['convention'] as Json).values.join(' '),
      }, containsAll(['z right', 'z left', 'y right', 'y left']));
      for (final c in cases) {
        final name = c['name'] as String;
        final grid = _build(c['input'] as Json);
        final output = c['output'] as Json;
        expect(
          grid.minorStep,
          closeTo(jsonNumber(output['minorStep']), vectorTolerance),
          reason: '$name minorStep',
        );
        expect(
          grid.majorStep,
          closeTo(jsonNumber(output['majorStep']), vectorTolerance),
          reason: '$name majorStep',
        );
        final expected = jsonList(output['primitives']);
        expect(grid.primitives, hasLength(expected.length), reason: name);
        for (var i = 0; i < expected.length; i++) {
          _expectPrimitive(grid.primitives[i], expected[i], '$name [$i]');
        }
      }
    });
  }, skip: skip);
}
