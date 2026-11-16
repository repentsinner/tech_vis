import 'dart:io';

import 'package:tech_vis/tech_vis.dart';
import 'package:test/test.dart';
import 'package:vector_math/vector_math_64.dart' as vm;

/// Absolute tolerance on every golden-vector number, in the function's own
/// units. Every recorded value comes from 64-bit math.
const vectorTolerance = 1e-9;

/// A decoded JSON object.
typedef Json = Map<String, dynamic>;

/// The fixture file [name] in the repository's `vectors/` directory.
///
/// The fixtures sit outside the package, so they exist in a repository
/// checkout and are absent from the published archive.
File vectorFixture(String name) => File('../vectors/$name');

/// The reason to skip a fixture test, or null when [fixture] exists.
String? skipUnlessPresent(File fixture) =>
    fixture.existsSync() ? null : 'vectors/ is outside the published archive';

double jsonNumber(Object? json) => (json! as num).toDouble();

List<double> jsonNumbers(Object? json) =>
    (json! as List<dynamic>).map(jsonNumber).toList();

vm.Vector3 jsonVector3(Object? json) => vm.Vector3.array(jsonNumbers(json));

/// Decodes a fixture's viewport-overlay placement record.
ViewportOverlayPlacement jsonPlacement(Object? json) {
  final p = json! as Json;
  return ViewportOverlayPlacement(
    corner: ViewportCorner.values.byName(p['corner'] as String),
    offsetXPixels: jsonNumber(p['offsetXPixels']),
    offsetYPixels: jsonNumber(p['offsetYPixels']),
    widthPixels: jsonNumber(p['widthPixels']),
    heightPixels: jsonNumber(p['heightPixels']),
  );
}

/// Decodes a fixture's `{up, handedness}` convention record.
CoordinateConvention jsonConvention(Object? json) {
  final c = json! as Json;
  return CoordinateConvention(
    up: SpatialAxis.values.byName(c['up'] as String),
    handedness: Handedness.values.byName(c['handedness'] as String),
  );
}

/// Decodes a fixture's `{axis, negative}` signed-axis record.
SignedAxis jsonSignedAxis(Object? json) {
  final a = json! as Json;
  return SignedAxis(
    SpatialAxis.values.byName(a['axis'] as String),
    negative: a['negative'] as bool,
  );
}

vm.Vector2 jsonVector2(Object? json) => vm.Vector2.array(jsonNumbers(json));

List<Json> jsonList(Object? json) => (json! as List<dynamic>).cast<Json>();

LeaderLineStyle jsonLeaderLineStyle(Object? json) {
  final s = json! as Json;
  return LeaderLineStyle(
    lineWidth: jsonNumber(s['lineWidth']),
    gapPixels: jsonNumber(s['gapPixels']),
    angledLengthPixels: jsonNumber(s['angledLengthPixels']),
    horizontalLengthPixels: jsonNumber(s['horizontalLengthPixels']),
    angleDegrees: jsonNumber(s['angleDegrees']),
  );
}

/// Expects [actual] to match the recorded numbers [expected], each within
/// [vectorTolerance].
void expectNumbers(List<double> actual, Object? expected, String reason) {
  final want = jsonNumbers(expected);
  expect(actual, hasLength(want.length), reason: reason);
  for (var i = 0; i < want.length; i++) {
    expect(actual[i], closeTo(want[i], vectorTolerance), reason: '$reason[$i]');
  }
}
