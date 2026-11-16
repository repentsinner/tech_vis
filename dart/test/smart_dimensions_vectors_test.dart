import 'dart:convert';
import 'dart:math' as math;

import 'package:tech_vis/tech_vis.dart';
import 'package:test/test.dart';

import 'support/fake_text_resolver.dart';
import 'support/vectors.dart';

final _fixture = vectorFixture('smart_dimensions.json');

DimensionStyle _style(Object? json) {
  final s = json! as Json;
  return DimensionStyle(
    lineWidth: jsonNumber(s['lineWidth']),
    witnessGapPixels: s['witnessGapPixels'] == null
        ? null
        : jsonNumber(s['witnessGapPixels']),
    witnessExtensionPixels: jsonNumber(s['witnessExtensionPixels']),
    offsetPixels: jsonNumber(s['offsetPixels']),
    arrowLengthPixels: jsonNumber(s['arrowLengthPixels']),
    arrowWidthPixels: jsonNumber(s['arrowWidthPixels']),
    textPixelSize: jsonNumber(s['textPixelSize']),
    textGapPixels: jsonNumber(s['textGapPixels']),
    alignmentTolerance: jsonNumber(s['alignmentTolerance']),
    leader: jsonLeaderLineStyle(s['leader']),
    arcRadiusPixels: jsonNumber(s['arcRadiusPixels']),
    arcSegmentPixels: jsonNumber(s['arcSegmentPixels']),
    angleResolutionDegrees: jsonNumber(s['angleResolutionDegrees']),
  );
}

/// The camera a case's `{position, target, ...}` record and [convention]
/// describe.
CameraBasis _camera(Json camera, CoordinateConvention convention) =>
    CameraBasis.lookAt(
      position: jsonVector3(camera['position']),
      target: jsonVector3(camera['target']),
      convention: convention,
    );

List<Primitive> _createAngular(Json input) {
  final camera = input['camera'] as Json;
  return SmartDimensionFactory.createAngular(
    vertex: jsonVector3(input['vertex']),
    first: jsonVector3(input['first']),
    second: jsonVector3(input['second']),
    convention: DraftingConvention.values.byName(input['drafting'] as String),
    camera: _camera(camera, jsonConvention(input['convention'])),
    verticalFovRadians:
        jsonNumber(camera['verticalFovDegrees']) * math.pi / 180,
    viewportSize: jsonVector2(camera['viewport']),
    resolveText: fakeTextResolver,
    key: null,
    numbers: jsonNumberFormatting(input['numbers']),
    style: _style(input['style']),
  );
}

List<Primitive> _createRadial(Json input) {
  final camera = input['camera'] as Json;
  return SmartDimensionFactory.createRadial(
    center: jsonVector3(input['center']),
    radius: jsonNumber(input['radius']),
    normal: jsonVector3(input['normal']),
    measure: RadialMeasure.values.byName(input['measure'] as String),
    convention: DraftingConvention.values.byName(input['drafting'] as String),
    format: DisplayFormat.values.byName(input['format'] as String),
    worldUnits: UnitSystem.values.byName(input['worldUnits'] as String),
    camera: _camera(camera, jsonConvention(input['convention'])),
    verticalFovRadians:
        jsonNumber(camera['verticalFovDegrees']) * math.pi / 180,
    viewportSize: jsonVector2(camera['viewport']),
    resolveText: fakeTextResolver,
    key: null,
    direction: input['direction'] == null
        ? null
        : jsonVector3(input['direction']),
    numbers: jsonNumberFormatting(input['numbers']),
    style: _style(input['style']),
  );
}

/// Expects every case of [cases] to emit its recorded primitives.
void _expectCases(Object? cases, List<Primitive> Function(Json) create) {
  final list = jsonList(cases);
  expect(list, isNotEmpty);
  for (final c in list) {
    final name = c['name'] as String;
    final want = jsonList((c['output'] as Json)['primitives']);
    final actual = create(c['input'] as Json);
    expect(actual, hasLength(want.length), reason: name);
    for (var i = 0; i < want.length; i++) {
      expectWorldPrimitive(actual[i], want[i], '$name [$i]');
    }
  }
}

List<Primitive> _create(Json input) {
  final camera = input['camera'] as Json;
  return SmartDimensionFactory.create(
    from: jsonVector3(input['from']),
    to: jsonVector3(input['to']),
    convention: DraftingConvention.values.byName(input['drafting'] as String),
    format: DisplayFormat.values.byName(input['format'] as String),
    worldUnits: UnitSystem.values.byName(input['worldUnits'] as String),
    camera: _camera(camera, jsonConvention(input['convention'])),
    verticalFovRadians:
        jsonNumber(camera['verticalFovDegrees']) * math.pi / 180,
    viewportSize: jsonVector2(camera['viewport']),
    resolveText: fakeTextResolver,
    key: null,
    multiAxis: MultiAxisDimension.values.byName(input['multiAxis'] as String),
    offsetDirection: input['offsetDirection'] == null
        ? null
        : jsonVector3(input['offsetDirection']),
    numbers: jsonNumberFormatting(input['numbers']),
    style: _style(input['style']),
  );
}

void main() {
  final skip = skipUnlessPresent(_fixture);

  group('smart-dimension golden vectors', () {
    late Json fixture;

    setUpAll(() {
      fixture = jsonDecode(_fixture.readAsStringSync()) as Json;
    });

    test('are generated from the current style version', () {
      expect(fixture['styleVersion'], StyleTokens.styleVersion);
    });

    test('use the stand-in typeface', () {
      final resolver = fixture['textResolver'] as Json;
      expect(resolver['characterWidthPerHeight'], fakeCharacterAspect);
    });

    test('SmartDimensionFactory.create', () {
      _expectCases(fixture['SmartDimensionFactory.create'], _create);
    });

    test('SmartDimensionFactory.createAngular', () {
      _expectCases(
        fixture['SmartDimensionFactory.createAngular'],
        _createAngular,
      );
    });

    test('SmartDimensionFactory.createRadial', () {
      _expectCases(
        fixture['SmartDimensionFactory.createRadial'],
        _createRadial,
      );
    });
  }, skip: skip);
}
