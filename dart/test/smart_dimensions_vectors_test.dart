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
  final convention = input['convention'] as Json;
  final camera = input['camera'] as Json;
  final numbers = input['numbers'] as Json;
  final space = CoordinateConvention(
    up: SpatialAxis.values.byName(convention['up'] as String),
    handedness: Handedness.values.byName(convention['handedness'] as String),
  );
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
    numbers: NumberFormatting(
      decimalMarker: DecimalMarker.values.byName(
        numbers['decimalMarker'] as String,
      ),
      showLeadingZero: numbers['showLeadingZero'] as bool,
    ),
    style: _style(input['style']),
  );
}

void _expectPrimitive(Primitive actual, Json want, String reason) {
  expect(actual, isA<Primitive>());
  switch (actual) {
    case LinePrimitive():
      expect(want['type'], 'line', reason: reason);
      expectNumbers(actual.start.storage, want['start'], '$reason start');
      expectNumbers(actual.end.storage, want['end'], '$reason end');
      expect(
        actual.widthPixels,
        closeTo(jsonNumber(want['widthPixels']), vectorTolerance),
        reason: '$reason width',
      );
    case BillboardPrimitive():
      expect(want['type'], 'billboard', reason: reason);
      expectNumbers(actual.anchor.storage, want['anchor'], '$reason anchor');
      expectNumbers(
        actual.alignment.storage,
        want['alignment'],
        '$reason alignment',
      );
      final orientation = want['orientation'] as Json;
      switch (actual.orientation) {
        case ViewerFacingOrientation():
          expect(orientation['type'], 'viewerFacing', reason: reason);
        case CoplanarOrientation(:final normal, :final right):
          expect(orientation['type'], 'coplanar', reason: reason);
          expectNumbers(normal.storage, orientation['normal'], '$reason n');
          expectNumbers(right.storage, orientation['right'], '$reason r');
      }
      final offset = want['offset'] as Json?;
      if (offset == null) {
        expect(actual.offset, isNull, reason: '$reason offset');
      } else {
        expectNumbers(
          actual.offset!.direction.storage,
          offset['direction'],
          '$reason offset direction',
        );
        expect(
          actual.offset!.pixels,
          closeTo(jsonNumber(offset['pixels']), vectorTolerance),
          reason: '$reason offset pixels',
        );
      }
      final request = want['textRequest'] as Json;
      expect(
        actual.content.value,
        TextRequest(
          text: request['text'] as String,
          heightPixels: jsonNumber(request['heightPixels']),
        ),
        reason: '$reason text',
      );
      expectNumbers(
        [actual.content.widthPixels, actual.content.heightPixels],
        want['contentSize'],
        '$reason content size',
      );
    case QuadPrimitive() || MarkerPrimitive() || MeshPrimitive():
      fail('$reason: a dimension emits lines and billboards');
  }
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
          _expectPrimitive(actual[i], want[i], '$name [$i]');
        }
      }
    });
  }, skip: skip);
}
