import 'dart:convert';

import 'package:tech_vis/tech_vis.dart';
import 'package:test/test.dart';
import 'package:vector_math/vector_math_64.dart' as vm;

import 'support/vectors.dart';

final _fixture = vectorFixture('navigation_cube.json');

CoordinateConvention _convention(Object? json) {
  final c = json! as Json;
  return CoordinateConvention(
    up: SpatialAxis.values.byName(c['up'] as String),
    handedness: Handedness.values.byName(c['handedness'] as String),
  );
}

NavigationCube _cube(Json input) => NavigationCube(
  convention: _convention(input['convention']),
  front: input['front'] == null ? null : jsonVector3(input['front']),
);

List<double> _numbers(vm.Vector v) => List.of(v.storage);

void main() {
  final skip = skipUnlessPresent(_fixture);

  group('navigation-cube golden vectors', () {
    late Json fixture;

    setUpAll(() {
      fixture = jsonDecode(_fixture.readAsStringSync()) as Json;
    });

    test('are generated from the current style version', () {
      expect(fixture['styleVersion'], StyleTokens.styleVersion);
    });

    test('NavigationCube.faces', () {
      final cases = jsonList(fixture['NavigationCube.faces']);
      expect(cases, isNotEmpty);
      for (final c in cases) {
        final cube = _cube(c['input'] as Json);
        final output = c['output'] as Json;
        expect(output.keys, NavigationCubeFace.values.map((f) => f.name));
        for (final face in NavigationCubeFace.values) {
          final want = output[face.name] as Json;
          final reason = '${c['name']}, ${face.name}';
          expect(face.label, want['label'], reason: reason);
          expectNumbers(_numbers(cube.normal(face)), want['normal'], reason);
          expectNumbers(
            _numbers(cube.textRight(face)),
            want['textRight'],
            reason,
          );
          expectNumbers(_numbers(cube.textUp(face)), want['textUp'], reason);
        }
      }
    });

    test('NavigationCube.visibleFaces', () {
      final cases = jsonList(fixture['NavigationCube.visibleFaces']);
      expect(cases, isNotEmpty);
      for (final c in cases) {
        final input = c['input'] as Json;
        final name = c['name'] as String;
        final camera = CameraBasis.lookAt(
          position: jsonVector3(input['cameraPosition']),
          target: jsonVector3(input['cameraTarget']),
          convention: _convention(input['convention']),
        );
        final [left, top, right, bottom] = jsonNumbers(input['rect']);
        final seen = _cube(input).visibleFaces(camera, (
          left: left,
          top: top,
          right: right,
          bottom: bottom,
        ));
        final want = jsonList((c['output'] as Json)['faces']);
        expect(
          seen.map((v) => v.face.name),
          want.map((w) => w['face']),
          reason: name,
        );
        for (final (i, view) in seen.indexed) {
          final reason = '$name, ${view.face.name}';
          expect(view.face.label, want[i]['label'], reason: reason);
          expect(
            view.facing,
            closeTo(jsonNumber(want[i]['facing']), vectorTolerance),
            reason: reason,
          );
          expectNumbers(
            [for (final p in view.corners) ..._numbers(p)],
            [for (final p in want[i]['corners'] as List<dynamic>) ...p as List],
            reason,
          );
        }
      }
    });
  }, skip: skip);
}
