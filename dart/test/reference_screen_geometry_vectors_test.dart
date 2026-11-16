import 'dart:convert';
import 'dart:math' as math;

import 'package:tech_vis/tech_vis.dart';
import 'package:test/test.dart';
import 'package:vector_math/vector_math_64.dart' as vm;

import 'support/fake_text_resolver.dart';
import 'support/pinhole.dart';
import 'support/vectors.dart';

final _fixture = vectorFixture('reference_screen_geometry.json');

CoordinateConvention _convention(Json json) => CoordinateConvention(
  up: SpatialAxis.values.byName(json['up'] as String),
  handedness: Handedness.values.byName(json['handedness'] as String),
);

/// One camera and viewport, read from a fixture view.
class _Frame {
  _Frame(Json json, CoordinateConvention convention)
    : camera = CameraBasis.lookAt(
        position: jsonVector3(json['position']),
        target: jsonVector3(json['target']),
        convention: convention,
      ),
      fovRadians = jsonNumber(json['verticalFovDegrees']) * math.pi / 180,
      viewport = jsonVector2(json['viewport']);

  final CameraBasis camera;
  final double fovRadians;
  final vm.Vector2 viewport;

  vm.Vector2 screen(vm.Vector3 point) =>
      ScreenSpaceUtils.worldToScreen(point, camera, fovRadians, viewport)!;

  double worldUnitsPerPixelAt(vm.Vector3 point) =>
      ScreenSpaceUtils.worldUnitsPerPixelAt(
        point,
        camera,
        fovRadians,
        viewport.y,
      )!;
}

/// Rebuilds a scene's primitives through the public factories, from the
/// inputs the fixture records.
List<Primitive> _build(
  Json build,
  CoordinateConvention convention,
  _Frame frame,
) {
  switch (build['factory']) {
    case 'BoundingBoxFactory.createCube':
      return BoundingBoxFactory.createCube(
        bounds: BoundingBox(
          minBounds: jsonVector3(build['minBounds']),
          maxBounds: jsonVector3(build['maxBounds']),
        ),
        key: null,
        fillOpacity: jsonNumber(build['fillOpacity']),
        edgeWidth: jsonNumber(build['edgeWidth']),
      );
    case 'CoordinateFrameFactory.create':
      return CoordinateFrameFactory.create(
        CoordinateFrameDescriptor(
          origin: jsonVector3(build['origin']),
          length: jsonNumber(build['length']),
          lineThickness: jsonNumber(build['lineThickness']),
          labelPixelSize: jsonNumber(build['labelPixelSize']),
          labelOffsetPixels: jsonNumber(build['labelOffsetPixels']),
        ),
        keyFor: (_) => null,
        resolveText: fakeTextResolver,
      );
    case 'createCalloutLabel':
      final style = jsonLeaderLineStyle(build['style'] as Json);
      final primitives = <Primitive>[];
      for (final c in jsonList(build['callouts'])) {
        final anchor = jsonVector3(c['anchor']);
        final quadrant = CalloutQuadrant.values.byName(c['quadrant'] as String);
        final leader = computeCalloutLeaderGeometry(
          anchor: anchor,
          cameraRight: frame.camera.right,
          cameraUp: frame.camera.up,
          worldUnitsPerPixel: frame.worldUnitsPerPixelAt(anchor),
          quadrant: quadrant,
          style: style,
        );
        primitives
          ..addAll(
            createCalloutLeaderLines(leader: leader, key: null, opacity: 1),
          )
          ..add(
            createCalloutLabel(
              leader: leader,
              quadrant: quadrant,
              content: fakeTextResolver(
                TextRequest(
                  text: c['text'] as String,
                  heightPixels: jsonNumber(c['textHeightPixels']),
                ),
              ),
              key: null,
              opacity: 1,
            ),
          );
      }
      return primitives;
    case 'MarkerFactory.create':
      return [
        for (final m in jsonList(build['markers']))
          MarkerFactory.create(
            position: jsonVector3(m['position']),
            convention: convention,
            key: null,
            diameterPixels: jsonNumber(m['diameterPixels']),
          ),
      ];
    default:
      throw ArgumentError.value(build['factory'], 'factory');
  }
}

/// Every screen point a recorded primitive names.
Iterable<List<double>> _points(Json record) sync* {
  for (final MapEntry(:key, :value) in record.entries) {
    switch (key) {
      case 'start' || 'end' || 'center' || 'anchor':
        yield jsonNumbers(value);
      case 'corners':
        yield* (value as List<dynamic>).map(jsonNumbers);
      case 'box':
        final [left, top, right, bottom] = jsonNumbers(value);
        yield [left, top];
        yield [right, bottom];
    }
  }
}

void _expectPrimitive(
  Primitive primitive,
  Json record,
  _Frame frame,
  String reason,
) {
  switch (primitive) {
    case LinePrimitive(:final start, :final end, :final widthPixels):
      expect(record['type'], 'line', reason: reason);
      expectNumbers(frame.screen(start).storage, record['start'], reason);
      expectNumbers(frame.screen(end).storage, record['end'], reason);
      expect(
        jsonNumber(record['widthPixels']),
        closeTo(widthPixels, vectorTolerance),
        reason: reason,
      );
    case QuadPrimitive(:final corners):
      expect(record['type'], 'quad', reason: reason);
      final recorded = record['corners'] as List<dynamic>;
      expect(recorded, hasLength(corners.length), reason: reason);
      for (final (i, corner) in corners.indexed) {
        expectNumbers(frame.screen(corner).storage, recorded[i], reason);
      }
    case BillboardPrimitive():
      expect(record['type'], 'billboard', reason: reason);
      _expectBillboard(primitive, record, frame, reason);
    case MarkerPrimitive():
      expect(record['type'], 'marker', reason: reason);
      _expectMarker(primitive, record, frame, reason);
    case MeshPrimitive():
      fail('$reason: no sample scene emits a mesh');
  }
}

void _expectBillboard(
  BillboardPrimitive billboard,
  Json record,
  _Frame frame,
  String reason,
) {
  final offset = billboard.offset;
  final placed = offset == null
      ? billboard.anchor
      : billboardOffsetPosition(
          anchor: billboard.anchor,
          direction: offset.direction,
          offsetPixels: offset.pixels,
          worldUnitsPerPixel: frame.worldUnitsPerPixelAt(billboard.anchor),
          camera: frame.camera,
        );
  final anchor = frame.screen(placed);
  expectNumbers(anchor.storage, record['anchor'], '$reason anchor');
  if (offset != null) {
    // The label sits its offset in pixels from the axis end on screen.
    expect(
      (anchor - frame.screen(billboard.anchor)).length,
      closeTo(offset.pixels, vectorTolerance),
      reason: '$reason offset',
    );
  }
  expectNumbers(
    billboard.alignment.storage,
    record['alignment'],
    '$reason alignment',
  );

  final request = record['textRequest'] as Json;
  expect(billboard.content.value, isA<TextRequest>(), reason: reason);
  final asked = billboard.content.value! as TextRequest;
  expect(request['text'], asked.text, reason: reason);
  expect(
    jsonNumber(request['heightPixels']),
    closeTo(asked.heightPixels, vectorTolerance),
    reason: reason,
  );
  final size = jsonNumbers(record['contentSize']);
  expectNumbers(
    [billboard.content.widthPixels, billboard.content.heightPixels],
    size,
    '$reason contentSize',
  );

  // The box follows from the font-independent anchor and alignment and
  // the recorded content size, so a renderer can rebuild it from its own.
  final [width, height] = size;
  final left = anchor.x - billboard.alignment.x * width;
  final top = anchor.y - (1 - billboard.alignment.y) * height;
  expectNumbers(
    [left, top, left + width, top + height],
    record['box'],
    '$reason box',
  );
}

void _expectMarker(
  MarkerPrimitive marker,
  Json record,
  _Frame frame,
  String reason,
) {
  expectNumbers(
    frame.screen(marker.position).storage,
    record['center'],
    '$reason center',
  );
  final transform = MarkerFactory.transform(
    marker,
    frame.camera,
    frame.fovRadians,
    frame.viewport.y,
  )!;
  final radius = transform.getMaxScaleOnAxis();
  final across =
      frame.screen(marker.position + frame.camera.right * radius) -
      frame.screen(marker.position - frame.camera.right * radius);
  expect(
    jsonNumber(record['diameterPixels']),
    closeTo(across.x, vectorTolerance),
    reason: '$reason diameter',
  );
  // A marker draws at its pixel diameter at any depth.
  expect(
    jsonNumber(record['diameterPixels']),
    closeTo(marker.diameterPixels, vectorTolerance),
    reason: '$reason diameter',
  );
}

/// Expects each callout's leader lines, emitted before its label, to keep
/// their style lengths in pixels on screen: the angled segment, then the
/// horizontal one.
void _expectLeaderLengths(
  List<Primitive> primitives,
  LeaderLineStyle style,
  _Frame frame,
  String reason,
) {
  final lines = primitives.whereType<LinePrimitive>().toList();
  expect(lines.length.isEven, isTrue, reason: reason);
  for (var i = 0; i < lines.length; i += 2) {
    for (final (line, pixels) in [
      (lines[i], style.angledLengthPixels),
      (lines[i + 1], style.horizontalLengthPixels),
    ]) {
      expect(
        (frame.screen(line.end) - frame.screen(line.start)).length,
        closeTo(pixels, vectorTolerance),
        reason: '$reason leader $i',
      );
    }
  }
}

void main() {
  final skip = skipUnlessPresent(_fixture);

  group('reference screen geometry vectors', () {
    late Json fixture;
    late List<Json> scenes;

    setUpAll(() {
      fixture = jsonDecode(_fixture.readAsStringSync()) as Json;
      scenes = jsonList(fixture['scenes']);
    });

    test('are generated from the current style version', () {
      expect(fixture['styleVersion'], StyleTokens.styleVersion);
    });

    test('record the stand-in typeface the content sizes come from', () {
      final resolver = fixture['textResolver'] as Json;
      expect(
        jsonNumber(resolver['characterWidthPerHeight']),
        fakeCharacterAspect,
      );
    });

    test('cover every factory, two up axes, and both handednesses', () {
      final conventions = {
        for (final s in scenes) _convention(s['convention'] as Json),
      };
      expect(conventions.map((c) => c.up).toSet(), hasLength(2));
      expect(conventions.map((c) => c.handedness).toSet(), Handedness.values);
      expect(
        {for (final s in scenes) (s['build'] as Json)['factory']},
        {
          'BoundingBoxFactory.createCube',
          'CoordinateFrameFactory.create',
          'createCalloutLabel',
          'MarkerFactory.create',
        },
      );
      final types = {
        for (final s in scenes)
          for (final v in jsonList(s['views']))
            for (final p in jsonList(v['primitives'])) p['type'],
      };
      expect(types, {'line', 'quad', 'billboard', 'marker'});
    });

    test('place every recorded point inside its viewport', () {
      for (final scene in scenes) {
        for (final view in jsonList(scene['views'])) {
          final [width, height] = jsonNumbers(
            (view['camera'] as Json)['viewport'],
          );
          final records = jsonList(view['primitives']);
          for (final record in records) {
            for (final [x, y] in _points(record)) {
              expect(x, inInclusiveRange(0, width), reason: '${scene['name']}');
              expect(
                y,
                inInclusiveRange(0, height),
                reason: '${scene['name']}',
              );
            }
          }
        }
      }
    });

    test('match each scene rebuilt and projected through the package', () {
      expect(scenes, isNotEmpty);
      for (final scene in scenes) {
        final convention = _convention(scene['convention'] as Json);
        final build = scene['build'] as Json;
        for (final view in jsonList(scene['views'])) {
          final reason = '${scene['name']} / ${view['name']}';
          final frame = _Frame(view['camera'] as Json, convention);
          final primitives = _build(build, convention, frame);

          final records = jsonList(view['primitives']);
          expect(records, hasLength(primitives.length), reason: reason);
          for (final (i, primitive) in primitives.indexed) {
            _expectPrimitive(primitive, records[i], frame, '$reason #$i');
          }

          if (build['factory'] == 'createCalloutLabel') {
            _expectLeaderLengths(
              primitives,
              jsonLeaderLineStyle(build['style'] as Json),
              frame,
              reason,
            );
          }
        }
      }
    });

    test('agree with an independent pinhole projection', () {
      for (final scene in scenes) {
        final convention = _convention(scene['convention'] as Json);
        for (final view in jsonList(scene['views'])) {
          final frame = _Frame(view['camera'] as Json, convention);
          final primitives = _build(scene['build'] as Json, convention, frame);
          final records = jsonList(view['primitives']);
          for (final (i, primitive) in primitives.indexed) {
            if (primitive is! LinePrimitive) continue;
            for (final (point, key) in [
              (primitive.start, 'start'),
              (primitive.end, 'end'),
            ]) {
              final centered = projectPinhole(
                point,
                frame.camera,
                verticalFovRadians: frame.fovRadians,
                viewportHeight: frame.viewport.y,
              );
              expectNumbers(
                [
                  frame.viewport.x / 2 + centered.x,
                  frame.viewport.y / 2 - centered.y,
                ],
                records[i][key],
                '${scene['name']} / ${view['name']} #$i $key',
              );
            }
          }
        }
      }
    });
  }, skip: skip);
}
