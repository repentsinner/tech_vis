import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:tech_vis/tech_vis.dart';
import 'package:test/test.dart';
import 'package:vector_math/vector_math_64.dart' as vm;

import 'support/fake_text_resolver.dart';
import 'support/pinhole.dart';

/// The fixtures sit outside the package, so they exist in a repository
/// checkout and are absent from the published archive.
final _fixture = File('../vectors/reference_screen_geometry.json');

/// Absolute tolerance on every number, in pixels. Every recorded value
/// comes from 64-bit math; none reads the 32-bit marker mesh, so the
/// golden-vector tolerance applies throughout.
const _tolerance = 1e-9;

typedef _Json = Map<String, dynamic>;

double _number(Object? json) => (json! as num).toDouble();

List<double> _numbers(Object? json) =>
    (json! as List<dynamic>).map(_number).toList();

vm.Vector3 _vector3(Object? json) => vm.Vector3.array(_numbers(json));

vm.Vector2 _vector2(Object? json) => vm.Vector2.array(_numbers(json));

List<_Json> _list(Object? json) => (json! as List<dynamic>).cast<_Json>();

void _expectNumbers(List<double> actual, Object? expected, String reason) {
  final want = _numbers(expected);
  expect(actual, hasLength(want.length), reason: reason);
  for (var i = 0; i < want.length; i++) {
    expect(actual[i], closeTo(want[i], _tolerance), reason: '$reason[$i]');
  }
}

CoordinateConvention _convention(_Json json) => CoordinateConvention(
  up: SpatialAxis.values.byName(json['up'] as String),
  handedness: Handedness.values.byName(json['handedness'] as String),
);

LeaderLineStyle _style(_Json s) => LeaderLineStyle(
  lineWidth: _number(s['lineWidth']),
  gapPixels: _number(s['gapPixels']),
  angledLengthPixels: _number(s['angledLengthPixels']),
  horizontalLengthPixels: _number(s['horizontalLengthPixels']),
  angleDegrees: _number(s['angleDegrees']),
);

/// One camera and viewport, read from a fixture view.
class _Frame {
  _Frame(_Json json, CoordinateConvention convention)
    : camera = CameraBasis.lookAt(
        position: _vector3(json['position']),
        target: _vector3(json['target']),
        convention: convention,
      ),
      fovRadians = _number(json['verticalFovDegrees']) * math.pi / 180,
      viewport = _vector2(json['viewport']);

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
({List<Primitive> primitives, List<CalloutLeaderGeometry> leaders}) _build(
  _Json build,
  CoordinateConvention convention,
  _Frame frame,
) {
  switch (build['factory']) {
    case 'BoundingBoxFactory.createCube':
      return (
        primitives: BoundingBoxFactory.createCube(
          bounds: BoundingBox(
            minBounds: _vector3(build['minBounds']),
            maxBounds: _vector3(build['maxBounds']),
          ),
          key: null,
          fillOpacity: _number(build['fillOpacity']),
          edgeWidth: _number(build['edgeWidth']),
        ),
        leaders: const [],
      );
    case 'CoordinateFrameFactory.create':
      return (
        primitives: CoordinateFrameFactory.create(
          CoordinateFrameDescriptor(
            origin: _vector3(build['origin']),
            length: _number(build['length']),
            lineThickness: _number(build['lineThickness']),
            labelPixelSize: _number(build['labelPixelSize']),
            labelOffsetPixels: _number(build['labelOffsetPixels']),
          ),
          keyFor: (_) => null,
          resolveText: fakeTextResolver,
        ),
        leaders: const [],
      );
    case 'createCalloutLabel':
      final style = _style(build['style'] as _Json);
      final primitives = <Primitive>[];
      final leaders = <CalloutLeaderGeometry>[];
      for (final c in _list(build['callouts'])) {
        final anchor = _vector3(c['anchor']);
        final quadrant = CalloutQuadrant.values.byName(c['quadrant'] as String);
        final leader = computeCalloutLeaderGeometry(
          anchor: anchor,
          cameraRight: frame.camera.right,
          cameraUp: frame.camera.up,
          worldUnitsPerPixel: frame.worldUnitsPerPixelAt(anchor),
          quadrant: quadrant,
          style: style,
        );
        leaders.add(leader);
        primitives.add(
          createCalloutLabel(
            leader: leader,
            quadrant: quadrant,
            content: fakeTextResolver(
              TextRequest(
                text: c['text'] as String,
                heightPixels: _number(c['textHeightPixels']),
              ),
            ),
            key: null,
            opacity: 1,
          ),
        );
      }
      return (primitives: primitives, leaders: leaders);
    case 'MarkerFactory.create':
      return (
        primitives: [
          for (final m in _list(build['markers']))
            MarkerFactory.create(
              position: _vector3(m['position']),
              convention: convention,
              key: null,
              diameterPixels: _number(m['diameterPixels']),
            ),
        ],
        leaders: const [],
      );
    default:
      throw ArgumentError.value(build['factory'], 'factory');
  }
}

/// Every screen point a recorded primitive or leader names.
Iterable<List<double>> _points(_Json record) sync* {
  for (final MapEntry(:key, :value) in record.entries) {
    switch (key) {
      case 'start' || 'end' || 'center' || 'anchor':
      case 'gapEnd' || 'elbow' || 'labelEdge':
        yield _numbers(value);
      case 'corners':
        yield* (value as List<dynamic>).map(_numbers);
      case 'box':
        final [left, top, right, bottom] = _numbers(value);
        yield [left, top];
        yield [right, bottom];
    }
  }
}

void _expectPrimitive(
  Primitive primitive,
  _Json record,
  _Frame frame,
  String reason,
) {
  switch (primitive) {
    case LinePrimitive(:final start, :final end, :final widthPixels):
      expect(record['type'], 'line', reason: reason);
      _expectNumbers(frame.screen(start).storage, record['start'], reason);
      _expectNumbers(frame.screen(end).storage, record['end'], reason);
      expect(
        _number(record['widthPixels']),
        closeTo(widthPixels, _tolerance),
        reason: reason,
      );
    case QuadPrimitive(:final corners):
      expect(record['type'], 'quad', reason: reason);
      final recorded = record['corners'] as List<dynamic>;
      expect(recorded, hasLength(corners.length), reason: reason);
      for (final (i, corner) in corners.indexed) {
        _expectNumbers(frame.screen(corner).storage, recorded[i], reason);
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
  _Json record,
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
  _expectNumbers(anchor.storage, record['anchor'], '$reason anchor');
  if (offset != null) {
    // The label sits its offset in pixels from the axis end on screen.
    expect(
      (anchor - frame.screen(billboard.anchor)).length,
      closeTo(offset.pixels, _tolerance),
      reason: '$reason offset',
    );
  }
  _expectNumbers(
    billboard.alignment.storage,
    record['alignment'],
    '$reason alignment',
  );

  final request = record['textRequest'] as _Json;
  expect(billboard.content.value, isA<TextRequest>(), reason: reason);
  final asked = billboard.content.value! as TextRequest;
  expect(request['text'], asked.text, reason: reason);
  expect(
    _number(request['heightPixels']),
    closeTo(asked.heightPixels, _tolerance),
    reason: reason,
  );
  final size = _numbers(record['contentSize']);
  _expectNumbers(
    [billboard.content.widthPixels, billboard.content.heightPixels],
    size,
    '$reason contentSize',
  );

  // The box follows from the font-independent anchor and alignment and
  // the recorded content size, so a renderer can rebuild it from its own.
  final [width, height] = size;
  final left = anchor.x - billboard.alignment.x * width;
  final top = anchor.y - (1 - billboard.alignment.y) * height;
  _expectNumbers(
    [left, top, left + width, top + height],
    record['box'],
    '$reason box',
  );
}

void _expectMarker(
  MarkerPrimitive marker,
  _Json record,
  _Frame frame,
  String reason,
) {
  _expectNumbers(
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
    _number(record['diameterPixels']),
    closeTo(across.x, _tolerance),
    reason: '$reason diameter',
  );
  // A marker draws at its pixel diameter at any depth.
  expect(
    _number(record['diameterPixels']),
    closeTo(marker.diameterPixels, _tolerance),
    reason: '$reason diameter',
  );
}

void _expectLeader(
  CalloutLeaderGeometry leader,
  vm.Vector3 anchor,
  LeaderLineStyle style,
  _Json record,
  _Frame frame,
  String reason,
) {
  final points = {
    'anchor': frame.screen(anchor),
    'gapEnd': frame.screen(leader.gapEnd),
    'elbow': frame.screen(leader.elbow),
    'labelEdge': frame.screen(leader.labelEdge),
  };
  for (final MapEntry(:key, :value) in points.entries) {
    _expectNumbers(value.storage, record[key], '$reason $key');
  }
  expect(
    _number(record['widthPixels']),
    closeTo(style.lineWidth, _tolerance),
    reason: reason,
  );
  // Each leader segment keeps its style length in pixels on screen.
  final lengths = {
    'gap': (points['gapEnd']! - points['anchor']!, style.gapPixels),
    'angled': (points['elbow']! - points['gapEnd']!, style.angledLengthPixels),
    'horizontal': (
      points['labelEdge']! - points['elbow']!,
      style.horizontalLengthPixels,
    ),
  };
  for (final MapEntry(:key, value: (segment, pixels)) in lengths.entries) {
    expect(segment.length, closeTo(pixels, _tolerance), reason: '$reason $key');
  }
}

void main() {
  final skip = _fixture.existsSync()
      ? null
      : 'vectors/ is outside the published archive';

  group('reference screen geometry vectors', () {
    late _Json fixture;
    late List<_Json> scenes;

    setUpAll(() {
      fixture = jsonDecode(_fixture.readAsStringSync()) as _Json;
      scenes = _list(fixture['scenes']);
    });

    test('are generated from the current style version', () {
      expect(fixture['styleVersion'], StyleTokens.styleVersion);
    });

    test('record the stand-in typeface the content sizes come from', () {
      final resolver = fixture['textResolver'] as _Json;
      expect(_number(resolver['characterWidthPerHeight']), fakeCharacterAspect);
    });

    test('cover every factory, two up axes, and both handednesses', () {
      final conventions = {
        for (final s in scenes) _convention(s['convention'] as _Json),
      };
      expect(conventions.map((c) => c.up).toSet(), hasLength(2));
      expect(conventions.map((c) => c.handedness).toSet(), Handedness.values);
      expect(
        {for (final s in scenes) (s['build'] as _Json)['factory']},
        {
          'BoundingBoxFactory.createCube',
          'CoordinateFrameFactory.create',
          'createCalloutLabel',
          'MarkerFactory.create',
        },
      );
      final types = {
        for (final s in scenes)
          for (final v in _list(s['views']))
            for (final p in _list(v['primitives'])) p['type'],
      };
      expect(types, {'line', 'quad', 'billboard', 'marker'});
    });

    test('place every recorded point inside its viewport', () {
      for (final scene in scenes) {
        for (final view in _list(scene['views'])) {
          final [width, height] = _numbers(
            (view['camera'] as _Json)['viewport'],
          );
          final records = [
            ..._list(view['primitives']),
            ..._list(view['leaders'] ?? const <dynamic>[]),
          ];
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
        final convention = _convention(scene['convention'] as _Json);
        final build = scene['build'] as _Json;
        for (final view in _list(scene['views'])) {
          final reason = '${scene['name']} / ${view['name']}';
          final frame = _Frame(view['camera'] as _Json, convention);
          final (:primitives, :leaders) = _build(build, convention, frame);

          final records = _list(view['primitives']);
          expect(records, hasLength(primitives.length), reason: reason);
          for (final (i, primitive) in primitives.indexed) {
            _expectPrimitive(primitive, records[i], frame, '$reason #$i');
          }

          final leaderRecords = _list(view['leaders'] ?? const <dynamic>[]);
          expect(leaderRecords, hasLength(leaders.length), reason: reason);
          for (final (i, leader) in leaders.indexed) {
            final callout = _list(build['callouts'])[i];
            _expectLeader(
              leader,
              _vector3(callout['anchor']),
              _style(build['style'] as _Json),
              leaderRecords[i],
              frame,
              '$reason leader $i',
            );
          }
        }
      }
    });

    test('agree with an independent pinhole projection', () {
      for (final scene in scenes) {
        final convention = _convention(scene['convention'] as _Json);
        for (final view in _list(scene['views'])) {
          final frame = _Frame(view['camera'] as _Json, convention);
          final (:primitives, leaders: _) = _build(
            scene['build'] as _Json,
            convention,
            frame,
          );
          final records = _list(view['primitives']);
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
              _expectNumbers(
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
