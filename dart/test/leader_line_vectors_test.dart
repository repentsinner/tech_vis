import 'dart:convert';
import 'dart:io';

import 'package:tech_vis/tech_vis.dart';
import 'package:test/test.dart';
import 'package:vector_math/vector_math_64.dart' as vm;

/// The fixtures sit outside the package, so they exist in a repository
/// checkout and are absent from the published archive.
final _fixture = File('../vectors/leader_line.json');

/// Absolute tolerance on every numeric output, in the function's own units.
const _tolerance = 1e-9;

typedef _Json = Map<String, dynamic>;

List<_Json> _cases(_Json fixture, String function) =>
    (fixture[function] as List<dynamic>).cast<_Json>();

double _number(Object? json) => (json! as num).toDouble();

vm.Vector3 _vector3(Object? json) {
  final c = (json! as List<dynamic>).map(_number).toList();
  return vm.Vector3(c[0], c[1], c[2]);
}

CalloutQuadrant _quadrant(Object? json) =>
    CalloutQuadrant.values.byName(json! as String);

LeaderLineStyle _style(Object? json) {
  if (json == null) return const LeaderLineStyle();
  final s = json as _Json;
  return LeaderLineStyle(
    lineWidth: _number(s['lineWidth']),
    gapPixels: _number(s['gapPixels']),
    angledLengthPixels: _number(s['angledLengthPixels']),
    horizontalLengthPixels: _number(s['horizontalLengthPixels']),
    angleDegrees: _number(s['angleDegrees']),
  );
}

void _expectVector(vm.Vector actual, Object? expected, String reason) {
  final want = (expected! as List<dynamic>).map(_number).toList();
  expect(actual.storage, hasLength(want.length), reason: reason);
  for (var i = 0; i < want.length; i++) {
    expect(
      actual.storage[i],
      closeTo(want[i], _tolerance),
      reason: '$reason[$i]',
    );
  }
}

void main() {
  final skip = _fixture.existsSync()
      ? null
      : 'vectors/ is outside the published archive';

  group('leader-line golden vectors', () {
    late _Json fixture;

    setUp(() {
      fixture = jsonDecode(_fixture.readAsStringSync()) as _Json;
    });

    test('are generated from the current style version', () {
      expect(fixture['styleVersion'], StyleTokens.styleVersion);
    });

    test('computeCalloutLeaderGeometry', () {
      final cases = _cases(fixture, 'computeCalloutLeaderGeometry');
      expect(cases, isNotEmpty);
      for (final c in cases) {
        final input = c['input'] as _Json;
        final output = c['output'] as _Json;
        final result = computeCalloutLeaderGeometry(
          anchor: _vector3(input['anchor']),
          cameraRight: _vector3(input['cameraRight']),
          cameraUp: _vector3(input['cameraUp']),
          worldUnitsPerPixel: _number(input['worldUnitsPerPixel']),
          quadrant: _quadrant(input['quadrant']),
          style: _style(input['style']),
        );
        final name = c['name'] as String;
        _expectVector(result.gapEnd, output['gapEnd'], '$name gapEnd');
        _expectVector(result.elbow, output['elbow'], '$name elbow');
        _expectVector(result.labelEdge, output['labelEdge'], '$name labelEdge');
      }
    });

    test('calloutAnchorAlignment', () {
      final cases = _cases(fixture, 'calloutAnchorAlignment');
      expect(
        cases.map((c) => (c['input'] as _Json)['quadrant']).toSet(),
        CalloutQuadrant.values.map((q) => q.name).toSet(),
      );
      for (final c in cases) {
        final input = c['input'] as _Json;
        final output = c['output'] as _Json;
        _expectVector(
          calloutAnchorAlignment(_quadrant(input['quadrant'])),
          output['alignment'],
          c['name'] as String,
        );
      }
    });

    test('computeCalloutOpacity', () {
      final cases = _cases(fixture, 'computeCalloutOpacity');
      expect(cases, isNotEmpty);
      for (final c in cases) {
        final input = c['input'] as _Json;
        final output = c['output'] as _Json;
        expect(
          computeCalloutOpacity(_number(input['distance'])),
          closeTo(_number(output['opacity']), _tolerance),
          reason: c['name'] as String,
        );
      }
    });
  }, skip: skip);
}
