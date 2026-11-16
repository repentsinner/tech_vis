import 'dart:math' as math;

import 'package:tech_vis/tech_vis.dart';
import 'package:test/test.dart';
import 'package:vector_math/vector_math_64.dart' as vm;

import 'support/fake_text_resolver.dart';

const _tolerance = 1e-9;

const _zUp = CoordinateConvention(
  up: SpatialAxis.z,
  handedness: Handedness.right,
);

const _fovRadians = math.pi / 3;
final _viewport = vm.Vector2(1000, 1000);
const _depth = 400.0;

/// A top view of the Z-up XY plane: screen right is +X and screen up is
/// +Y, and every point on the plane sits at one depth, so pixel lengths
/// on the plane measure exactly.
final _topView = CameraBasis.lookAt(
  position: vm.Vector3(0, 0, _depth),
  target: vm.Vector3.zero(),
  convention: _zUp,
);

/// World units per pixel everywhere on the plane of [_topView].
final _pixel = 2 * _depth * math.tan(_fovRadians / 2) / _viewport.y;

final _x = vm.Vector3(1, 0, 0);
final _y = vm.Vector3(0, 1, 0);

/// A unit vector in the XY plane at [degrees] from +X.
vm.Vector3 _at(double degrees) {
  final r = degrees * math.pi / 180;
  return vm.Vector3(math.cos(r), math.sin(r), 0);
}

List<Primitive> _angular(
  vm.Vector3 first,
  vm.Vector3 second, {
  vm.Vector3? vertex,
  DraftingConvention convention = DraftingConvention.isoOriented,
  CameraBasis? camera,
  NumberFormatting numbers = const NumberFormatting(),
  DimensionStyle style = const DimensionStyle(),
  Object? key,
  double opacity = 1,
}) => SmartDimensionFactory.createAngular(
  vertex: vertex ?? vm.Vector3.zero(),
  first: first,
  second: second,
  convention: convention,
  camera: camera ?? _topView,
  verticalFovRadians: _fovRadians,
  viewportSize: _viewport,
  resolveText: fakeTextResolver,
  key: key,
  numbers: numbers,
  style: style,
  opacity: opacity,
);

List<BillboardPrimitive> _labels(List<Primitive> primitives) =>
    primitives.whereType<BillboardPrimitive>().toList();

List<String> _texts(List<Primitive> primitives) => [
  for (final b in _labels(primitives)) (b.content.value! as TextRequest).text,
];

List<LinePrimitive> _lines(List<Primitive> primitives) =>
    primitives.whereType<LinePrimitive>().toList();

void _expectVector(vm.Vector3 actual, vm.Vector3 expected, String reason) {
  for (var i = 0; i < 3; i++) {
    expect(actual[i], closeTo(expected[i], _tolerance), reason: '$reason[$i]');
  }
}

/// The arc's lines: those with both ends at [radius] from the origin.
List<LinePrimitive> _arc(List<Primitive> primitives, double radius) => [
  for (final l in _lines(primitives))
    if ((l.start.length - radius).abs() < 1e-6 &&
        (l.end.length - radius).abs() < 1e-6)
      l,
];

void main() {
  final radius = StyleTokens.dimensionArcRadiusPixels * _pixel;

  group('DimensionStyle arc and angle defaults', () {
    test('come from the style tokens', () {
      const style = DimensionStyle();
      expect(style.arcRadiusPixels, StyleTokens.dimensionArcRadiusPixels);
      expect(style.arcSegmentPixels, StyleTokens.dimensionArcSegmentPixels);
      expect(
        style.angleResolutionDegrees,
        StyleTokens.dimensionAngleResolutionDegrees,
      );
    });
  });

  group('angular dimension value', () {
    final cases = [
      (name: 'right angle', first: _x, second: _y * 3, want: '90°'),
      (name: 'acute', first: _x * 2, second: _at(45), want: '45°'),
      (name: 'obtuse', first: _at(10), second: _at(145.25), want: '135.3°'),
      (
        name: 'out of the plane',
        first: _x,
        second: vm.Vector3(0, 1, 1),
        want: '90°',
      ),
      (name: 'clockwise order', first: _at(60), second: _x, want: '60°'),
    ];
    for (final c in cases) {
      test(c.name, () {
        expect(_texts(_angular(c.first, c.second)), [c.want]);
      });
    }

    test('rounds to the style resolution with the app numbers', () {
      final texts = _texts(
        _angular(
          _x,
          _at(22.5),
          numbers: const NumberFormatting(decimalMarker: DecimalMarker.comma),
          style: const DimensionStyle(angleResolutionDegrees: 0.5),
        ),
      );
      expect(texts, ['22,5°']);
    });
  });

  group('angular dimension emits nothing', () {
    final cases = [
      (
        name: 'for a zero first vector',
        first: vm.Vector3.zero(),
        second: _y,
        vertex: null,
      ),
      (
        name: 'for a zero second vector',
        first: _x,
        second: vm.Vector3.zero(),
        vertex: null,
      ),
      (name: 'for parallel vectors', first: _x, second: _x * 4, vertex: null),
      (name: 'for opposed vectors', first: _x, second: -_x, vertex: null),
      (
        name: 'for a vertex behind the camera',
        first: _x,
        second: _y,
        vertex: vm.Vector3(0, 0, 2 * _depth),
      ),
    ];
    for (final c in cases) {
      test(c.name, () {
        expect(_angular(c.first, c.second, vertex: c.vertex), isEmpty);
      });
    }
  });

  group('angular dimension arc', () {
    final cases = [
      (name: 'quarter turn', second: _y, angle: math.pi / 2),
      (name: 'eighth turn', second: _at(45), angle: math.pi / 4),
      (name: 'near a half turn', second: _at(170), angle: 170 * math.pi / 180),
    ];
    for (final c in cases) {
      test('${c.name} runs at the radius token, one line per segment', () {
        final arc = _arc(
          _angular(
            _x * 100,
            c.second * 100,
            convention: DraftingConvention.isoReferencing,
          ),
          radius,
        );
        final segments =
            (StyleTokens.dimensionArcRadiusPixels *
                    c.angle /
                    StyleTokens.dimensionArcSegmentPixels)
                .ceil();
        expect(arc, hasLength(segments));
        _expectVector(arc.first.start, _x * radius, 'starts on the first leg');
        _expectVector(
          arc.last.end,
          c.second * radius,
          'ends on the second leg',
        );
        for (var i = 1; i < arc.length; i++) {
          _expectVector(arc[i].start, arc[i - 1].end, 'segment $i joins');
        }
        for (final l in arc) {
          expect(l.widthPixels, StyleTokens.dimensionLineWidth);
        }
      });
    }

    test('an inlined arc breaks around its midpoint for the text', () {
      final primitives = _angular(
        _x * 100,
        _y * 100,
        convention: DraftingConvention.asmeInlined,
      );
      final arc = _arc(primitives, radius);
      final label = _labels(primitives).single;
      _expectVector(label.anchor, _at(45) * radius, 'text at the midpoint');
      expect(label.orientation, isA<ViewerFacingOrientation>());
      // The break sits where consecutive arc lines no longer join.
      final breaks = [
        for (var i = 1; i < arc.length; i++)
          if ((arc[i].start - arc[i - 1].end).length > 1e-6) i,
      ];
      expect(breaks, hasLength(1));
      final before = arc[breaks.single - 1].end;
      final after = arc[breaks.single].start;
      // At 45 degrees on screen the text extent is its box projected onto
      // the arc's tangent.
      final content = label.content;
      final extent =
          (content.widthPixels + content.heightPixels) * math.sqrt1_2;
      final halfAngle =
          (extent / 2 + StyleTokens.dimensionTextGapPixels) /
          StyleTokens.dimensionArcRadiusPixels;
      _expectVector(
        before,
        _at(45 - halfAngle * 180 / math.pi) * radius,
        'before',
      );
      _expectVector(
        after,
        _at(45 + halfAngle * 180 / math.pi) * radius,
        'after',
      );
    });
  });

  group('angular dimension witness lines', () {
    test('extend a leg that ends short of the arc', () {
      final leg = radius / 2;
      final lines = _lines(
        _angular(
          _x * leg,
          _y * 100,
          convention: DraftingConvention.isoReferencing,
        ),
      );
      final witness = lines.first;
      final gap = StyleTokens.dimensionWitnessGapIsoPixels * _pixel;
      final extension = StyleTokens.dimensionWitnessExtensionPixels * _pixel;
      _expectVector(witness.start, _x * (leg + gap), 'starts past the gap');
      _expectVector(
        witness.end,
        _x * (radius + extension),
        'runs past the arc',
      );
    });

    test('are omitted where the legs reach the arc', () {
      final primitives = _angular(
        _x * 100,
        _y * 100,
        convention: DraftingConvention.isoReferencing,
      );
      final arc = _arc(primitives, radius);
      expect(identical(_lines(primitives).first, arc.first), isTrue);
    });

    test('use the ASME gap under ASME', () {
      final leg = radius / 4;
      final witness = _lines(
        _angular(
          _x * leg,
          _y * 100,
          convention: DraftingConvention.asmeReferencing,
        ),
      ).first;
      final gap = StyleTokens.dimensionWitnessGapAsmePixels * _pixel;
      _expectVector(witness.start, _x * (leg + gap), 'starts past the gap');
    });
  });

  group('angular dimension arrowheads', () {
    test('point along the arc into it at each end', () {
      final primitives = _angular(
        _x * 100,
        _y * 100,
        convention: DraftingConvention.isoReferencing,
      );
      final lines = _lines(primitives);
      final arcCount = _arc(primitives, radius).length;
      final barbs = lines.sublist(arcCount, arcCount + 4);
      final length = StyleTokens.dimensionArrowLengthPixels * _pixel;
      final halfWidth = StyleTokens.dimensionArrowWidthPixels / 2 * _pixel;
      final firstTip = _x * radius;
      final secondTip = _y * radius;
      for (final b in barbs.take(2)) {
        _expectVector(b.start, firstTip, 'first tip');
      }
      for (final b in barbs.skip(2)) {
        _expectVector(b.start, secondTip, 'second tip');
      }
      // The arc runs +Y from its first end and +X back from its second.
      final firstEnds = {
        for (final b in barbs.take(2)) (b.end.x * 1e6).round(),
      };
      expect(firstEnds, {
        ((radius + halfWidth) * 1e6).round(),
        ((radius - halfWidth) * 1e6).round(),
      });
      for (final b in barbs.take(2)) {
        expect(b.end.y, closeTo(length, _tolerance));
      }
      for (final b in barbs.skip(2)) {
        expect(b.end.x, closeTo(length, _tolerance));
      }
    });
  });

  group('angular dimension text', () {
    test('oriented text lies along the tangent at the arc midpoint', () {
      final primitives = _angular(_x * 100, _y * 100);
      final label = _labels(primitives).single;
      _expectVector(label.anchor, _at(45) * radius, 'at the midpoint');
      final orientation = label.orientation as CoplanarOrientation;
      // The tangent at 45 degrees runs toward -X, +Y; read left to right.
      _expectVector(orientation.right, _at(-45), 'reads along the tangent');
      _expectVector(label.offset!.direction, _at(45), 'lifted outward');
    });

    final referencing = [
      DraftingConvention.isoReferencing,
      DraftingConvention.asmeReferencing,
    ];
    for (final convention in referencing) {
      test('${convention.name} leads the text off the arc midpoint', () {
        final primitives = _angular(_x * 100, _y * 100, convention: convention);
        final label = _labels(primitives).single;
        final lines = _lines(primitives);
        final leader = lines.sublist(lines.length - 2);
        expect(label.orientation, isA<ViewerFacingOrientation>());
        _expectVector(leader.last.end, label.anchor, 'label at leader end');
        // The bisector points to top-right on screen: the leader leaves
        // there.
        expect(leader.first.start.x, greaterThan(_at(45).x * radius));
        expect(leader.first.start.y, greaterThan(_at(45).y * radius));
      });
    }

    final cramped = [
      DraftingConvention.isoOriented,
      DraftingConvention.asmeInlined,
    ];
    for (final convention in cramped) {
      test('${convention.name} falls back to referencing on a small angle', () {
        final primitives = _angular(
          _x * 100,
          _at(5) * 100,
          convention: convention,
        );
        final lines = _lines(primitives);
        final arc = _arc(primitives, radius);
        // Arc, four barbs, two leader lines.
        expect(lines, hasLength(arc.length + 6));
        expect(
          _labels(primitives).single.orientation,
          isA<ViewerFacingOrientation>(),
        );
      });
    }
  });

  test('angular dimension carries the key and opacity', () {
    final primitives = _angular(_x, _y, key: #angle, opacity: 0.4);
    for (final p in primitives) {
      expect(p.key, #angle);
      expect(p.opacity, 0.4);
    }
  });
}
