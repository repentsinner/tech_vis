import 'dart:math' as math;

import 'package:tech_vis/tech_vis.dart';
import 'package:test/test.dart';
import 'package:vector_math/vector_math_64.dart' as vm;

import 'support/fake_text_resolver.dart';
import 'support/primitives.dart';

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

/// The arc's lines: those with both ends at [radius] from the origin.
List<LinePrimitive> _arc(List<Primitive> primitives, double radius) => [
  for (final l in linesOf(primitives))
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
        expect(textsOf(_angular(c.first, c.second)), [c.want]);
      });
    }

    test('rounds to the style resolution with the app numbers', () {
      final texts = textsOf(
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
        expectVector3(arc.first.start, _x * radius, 'starts on the first leg');
        expectVector3(
          arc.last.end,
          c.second * radius,
          'ends on the second leg',
        );
        for (var i = 1; i < arc.length; i++) {
          expectVector3(arc[i].start, arc[i - 1].end, 'segment $i joins');
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
      final label = billboardsOf(primitives).single;
      expectVector3(label.anchor, _at(45) * radius, 'text at the midpoint');
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
      expectVector3(
        before,
        _at(45 - halfAngle * 180 / math.pi) * radius,
        'before',
      );
      expectVector3(
        after,
        _at(45 + halfAngle * 180 / math.pi) * radius,
        'after',
      );
    });
  });

  group('angular dimension witness lines', () {
    test('extend a leg that ends short of the arc', () {
      final leg = radius / 2;
      final lines = linesOf(
        _angular(
          _x * leg,
          _y * 100,
          convention: DraftingConvention.isoReferencing,
        ),
      );
      final witness = lines.first;
      final gap = StyleTokens.dimensionWitnessGapIsoPixels * _pixel;
      final extension = StyleTokens.dimensionWitnessExtensionPixels * _pixel;
      expectVector3(witness.start, _x * (leg + gap), 'starts past the gap');
      expectVector3(
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
      expect(identical(linesOf(primitives).first, arc.first), isTrue);
    });

    test('use the ASME gap under ASME', () {
      final leg = radius / 4;
      final witness = linesOf(
        _angular(
          _x * leg,
          _y * 100,
          convention: DraftingConvention.asmeReferencing,
        ),
      ).first;
      final gap = StyleTokens.dimensionWitnessGapAsmePixels * _pixel;
      expectVector3(witness.start, _x * (leg + gap), 'starts past the gap');
    });
  });

  group('angular dimension arrowheads', () {
    test('point along the arc into it at each end', () {
      final primitives = _angular(
        _x * 100,
        _y * 100,
        convention: DraftingConvention.isoReferencing,
      );
      final lines = linesOf(primitives);
      final arcCount = _arc(primitives, radius).length;
      final barbs = lines.sublist(arcCount, arcCount + 4);
      final length = StyleTokens.dimensionArrowLengthPixels * _pixel;
      final halfWidth = StyleTokens.dimensionArrowWidthPixels / 2 * _pixel;
      final firstTip = _x * radius;
      final secondTip = _y * radius;
      for (final b in barbs.take(2)) {
        expectVector3(b.start, firstTip, 'first tip');
      }
      for (final b in barbs.skip(2)) {
        expectVector3(b.start, secondTip, 'second tip');
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
      final label = billboardsOf(primitives).single;
      expectVector3(label.anchor, _at(45) * radius, 'at the midpoint');
      final orientation = label.orientation as CoplanarOrientation;
      // The tangent at 45 degrees runs toward -X, +Y; read left to right.
      expectVector3(orientation.right, _at(-45), 'reads along the tangent');
      expectVector3(label.offset!.direction, _at(45), 'lifted outward');
    });

    final referencing = [
      DraftingConvention.isoReferencing,
      DraftingConvention.asmeReferencing,
    ];
    for (final convention in referencing) {
      test('${convention.name} leads the text off the arc midpoint', () {
        final primitives = _angular(_x * 100, _y * 100, convention: convention);
        final label = billboardsOf(primitives).single;
        final lines = linesOf(primitives);
        final leader = lines.sublist(lines.length - 2);
        expect(label.orientation, isA<ViewerFacingOrientation>());
        expectVector3(leader.last.end, label.anchor, 'label at leader end');
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
        final lines = linesOf(primitives);
        final arc = _arc(primitives, radius);
        // Arc, four barbs, two leader lines.
        expect(lines, hasLength(arc.length + 6));
        expect(
          billboardsOf(primitives).single.orientation,
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
  group('radial dimension', () {
    final rim = _at(45) * 50;
    final cases = [
      (
        name: 'radius',
        measure: RadialMeasure.radius,
        format: DisplayFormat.metric,
        worldUnits: UnitSystem.metric,
        text: 'R50 mm',
        start: vm.Vector3.zero(),
      ),
      (
        name: 'diameter',
        measure: RadialMeasure.diameter,
        format: DisplayFormat.metric,
        worldUnits: UnitSystem.metric,
        text: '⌀100 mm',
        start: -rim,
      ),
      (
        name: 'diameter in fractional inch',
        measure: RadialMeasure.diameter,
        format: DisplayFormat.fractionalInch,
        worldUnits: UnitSystem.imperial,
        text: '⌀8\' 4"',
        start: -rim,
      ),
    ];
    for (final c in cases) {
      test('${c.name} runs toward screen top-right and reads ${c.text}', () {
        final primitives = _radial(
          50,
          measure: c.measure,
          format: c.format,
          worldUnits: c.worldUnits,
          convention: DraftingConvention.isoReferencing,
        );
        expect(textsOf(primitives), [c.text]);
        final lines = linesOf(primitives);
        expectVector3(lines.first.start, c.start, 'start');
        expectVector3(lines.first.end, rim, 'ends on the rim');
        final barbs = lines.sublist(1, lines.length - 2);
        final arrows = c.measure == RadialMeasure.radius ? 1 : 2;
        expect(barbs, hasLength(2 * arrows));
        final length = StyleTokens.dimensionArrowLengthPixels * _pixel;
        for (final b in barbs.take(2)) {
          expectVector3(b.start, rim, 'tip on the rim');
          // The base sits an arrowhead length back toward the center.
          expect((b.end - rim).dot(-_at(45)), closeTo(length, _tolerance));
        }
        for (final b in barbs.skip(2)) {
          expectVector3(b.start, -rim, 'tip on the far rim');
        }
      });
    }

    test('lies along the in-plane part of the app direction', () {
      final line = linesOf(
        _radial(
          50,
          direction: vm.Vector3(0, -1, 5),
          convention: DraftingConvention.isoReferencing,
        ),
      ).first;
      expectVector3(line.end, _y * -50, 'rim');
    });

    test('falls back to screen right when up-right is the normal', () {
      final normal = vm.Vector3(1, 1, 0).normalized();
      final line = linesOf(
        _radial(
          50,
          normal: normal,
          convention: DraftingConvention.isoReferencing,
        ),
      ).first;
      expectVector3(line.end, vm.Vector3(1, -1, 0).normalized() * 50, 'rim');
    });

    test('an inlined line breaks around its midpoint for the text', () {
      final primitives = _radial(
        50,
        convention: DraftingConvention.asmeInlined,
      );
      final lines = linesOf(primitives);
      final label = billboardsOf(primitives).single;
      final middle = rim / 2;
      expectVector3(label.anchor, middle, 'text at the midpoint');
      final content = label.content;
      final extent =
          (content.widthPixels + content.heightPixels) * math.sqrt1_2;
      final halfBreak =
          (extent / 2 + StyleTokens.dimensionTextGapPixels) * _pixel;
      expectVector3(lines[0].start, vm.Vector3.zero(), 'from the center');
      expectVector3(lines[0].end, middle - _at(45) * halfBreak, 'to the break');
      expectVector3(lines[1].start, middle + _at(45) * halfBreak, 'past it');
      expectVector3(lines[1].end, rim, 'to the rim');
    });

    test('oriented text lies along the line', () {
      final label = billboardsOf(_radial(50)).single;
      final orientation = label.orientation as CoplanarOrientation;
      expectVector3(orientation.right, _at(45), 'reads along the line');
    });

    for (final convention in [
      DraftingConvention.isoOriented,
      DraftingConvention.asmeInlined,
    ]) {
      test(
        '${convention.name} falls back to referencing on a small circle',
        () {
          final primitives = _radial(5, convention: convention);
          // Line, two barbs, two leader lines.
          expect(linesOf(primitives), hasLength(5));
          expect(
            billboardsOf(primitives).single.orientation,
            isA<ViewerFacingOrientation>(),
          );
        },
      );
    }

    final empty = [
      (name: 'a zero radius', radius: 0.0, normal: _z, center: null),
      (
        name: 'a zero normal',
        radius: 50.0,
        normal: vm.Vector3.zero(),
        center: null,
      ),
      (
        name: 'a center behind the camera',
        radius: 50.0,
        normal: _z,
        center: vm.Vector3(0, 0, 2 * _depth),
      ),
    ];
    for (final c in empty) {
      test('emits nothing for ${c.name}', () {
        expect(_radial(c.radius, normal: c.normal, center: c.center), isEmpty);
      });
    }

    test('carries the key and opacity', () {
      for (final p in _radial(50, key: #radius, opacity: 0.3)) {
        expect(p.key, #radius);
        expect(p.opacity, 0.3);
      }
    });
  });
}

final _z = vm.Vector3(0, 0, 1);

List<Primitive> _radial(
  double radius, {
  vm.Vector3? center,
  vm.Vector3? normal,
  RadialMeasure measure = RadialMeasure.radius,
  DraftingConvention convention = DraftingConvention.isoOriented,
  DisplayFormat format = DisplayFormat.metric,
  UnitSystem worldUnits = UnitSystem.metric,
  vm.Vector3? direction,
  Object? key,
  double opacity = 1,
}) => SmartDimensionFactory.createRadial(
  center: center ?? vm.Vector3.zero(),
  radius: radius,
  normal: normal ?? _z,
  measure: measure,
  convention: convention,
  format: format,
  worldUnits: worldUnits,
  camera: _topView,
  verticalFovRadians: _fovRadians,
  viewportSize: _viewport,
  resolveText: fakeTextResolver,
  key: key,
  direction: direction,
  opacity: opacity,
);
