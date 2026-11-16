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
  );
}

List<Primitive> _create(Json input) {
  final camera = input['camera'] as Json;
  final space = jsonConvention(input['convention']);
  return SmartDimensionFactory.create(
    from: jsonVector3(input['from']),
    to: jsonVector3(input['to']),
    convention: DraftingConvention.values.byName(input['drafting'] as String),
    format: DisplayFormat.values.byName(input['format'] as String),
    worldUnits: UnitSystem.values.byName(input['worldUnits'] as String),
    camera: CameraBasis.lookAt(
      position: jsonVector3(camera['position']),
      target: jsonVector3(camera['target']),
      convention: space,
    ),
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
      final cases = jsonList(fixture['SmartDimensionFactory.create']);
      expect(cases, isNotEmpty);
      for (final c in cases) {
        final name = c['name'] as String;
        final output = c['output'] as Json;
        final want = jsonList(output['primitives']);
        final actual = _create(c['input'] as Json);
        expect(actual, hasLength(want.length), reason: name);
        for (var i = 0; i < want.length; i++) {
          expectWorldPrimitive(actual[i], want[i], '$name [$i]');
        }
      }
    });
  }, skip: skip);
}
