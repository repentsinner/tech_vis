import 'dart:convert';

import 'package:tech_vis/tech_vis.dart';
import 'package:test/test.dart';

import 'support/vectors.dart';

final _fixture = vectorFixture('leader_line.json');

typedef _Case = ({String name, Json input, Json output});

List<_Case> _cases(Json fixture, String function) => [
  for (final c in (fixture[function] as List<dynamic>).cast<Json>())
    (
      name: c['name'] as String,
      input: c['input'] as Json,
      output: c['output'] as Json,
    ),
];

CalloutQuadrant _quadrant(Object? json) =>
    CalloutQuadrant.values.byName(json! as String);

void main() {
  final skip = skipUnlessPresent(_fixture);

  group('leader-line golden vectors', () {
    late Json fixture;

    setUpAll(() {
      fixture = jsonDecode(_fixture.readAsStringSync()) as Json;
    });

    test('are generated from the current style version', () {
      expect(fixture['styleVersion'], StyleTokens.styleVersion);
    });

    test('computeCalloutLeaderGeometry', () {
      final cases = _cases(fixture, 'computeCalloutLeaderGeometry');
      expect(cases, isNotEmpty);
      for (final (:name, :input, :output) in cases) {
        final result = computeCalloutLeaderGeometry(
          anchor: jsonVector3(input['anchor']),
          cameraRight: jsonVector3(input['cameraRight']),
          cameraUp: jsonVector3(input['cameraUp']),
          worldUnitsPerPixel: jsonNumber(input['worldUnitsPerPixel']),
          quadrant: _quadrant(input['quadrant']),
          style: jsonLeaderLineStyle(input['style']),
        );
        expectNumbers(result.gapEnd.storage, output['gapEnd'], '$name gapEnd');
        expectNumbers(result.elbow.storage, output['elbow'], '$name elbow');
        expectNumbers(
          result.labelEdge.storage,
          output['labelEdge'],
          '$name labelEdge',
        );
      }
    });

    test('calloutAnchorAlignment', () {
      final cases = _cases(fixture, 'calloutAnchorAlignment');
      expect(
        cases.map((c) => c.input['quadrant']).toSet(),
        CalloutQuadrant.values.map((q) => q.name).toSet(),
      );
      for (final (:name, :input, :output) in cases) {
        expectNumbers(
          calloutAnchorAlignment(_quadrant(input['quadrant'])).storage,
          output['alignment'],
          name,
        );
      }
    });

    test('computeCalloutOpacity', () {
      final cases = _cases(fixture, 'computeCalloutOpacity');
      expect(cases, isNotEmpty);
      for (final (:name, :input, :output) in cases) {
        expect(
          computeCalloutOpacity(jsonNumber(input['distance'])),
          closeTo(jsonNumber(output['opacity']), vectorTolerance),
          reason: name,
        );
      }
    });
  }, skip: skip);
}
