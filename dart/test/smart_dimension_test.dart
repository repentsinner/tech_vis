import 'dart:math' as math;

import 'package:tech_vis/tech_vis.dart';
import 'package:test/test.dart';
import 'package:vector_math/vector_math_64.dart' as vm;

import 'support/fake_text_resolver.dart';
import 'support/pinhole.dart';
import 'support/primitives.dart';

const _zUp = CoordinateConvention(
  up: SpatialAxis.z,
  handedness: Handedness.right,
);

const _fovRadians = math.pi / 3;
final _viewport = vm.Vector2(1000, 1000);

/// A top view of the Z-up XY plane: screen right is +X and screen up is
/// +Y, and every point on the plane sits at one depth, so pixel lengths
/// on the plane measure exactly.
final _topView = CameraBasis.lookAt(
  position: vm.Vector3(50, 0, 400),
  target: vm.Vector3(50, 0, 0),
  convention: _zUp,
);

List<Primitive> _dimension(
  vm.Vector3 from,
  vm.Vector3 to, {
  DraftingConvention convention = DraftingConvention.isoOriented,
  DisplayFormat format = DisplayFormat.metric,
  UnitSystem worldUnits = UnitSystem.metric,
  CameraBasis? camera,
  MultiAxisDimension multiAxis = MultiAxisDimension.components,
  vm.Vector3? offsetDirection,
  NumberFormatting numbers = const NumberFormatting(),
  DimensionStyle style = const DimensionStyle(),
  Object? key,
  double opacity = 1,
}) => SmartDimensionFactory.create(
  from: from,
  to: to,
  convention: convention,
  format: format,
  worldUnits: worldUnits,
  camera: camera ?? _topView,
  verticalFovRadians: _fovRadians,
  viewportSize: _viewport,
  resolveText: fakeTextResolver,
  key: key,
  multiAxis: multiAxis,
  offsetDirection: offsetDirection,
  numbers: numbers,
  style: style,
  opacity: opacity,
);

vm.Vector2 _px(vm.Vector3 point) => projectPinhole(
  point,
  _topView,
  verticalFovRadians: _fovRadians,
  viewportHeight: _viewport.y,
);

double _pxLength(vm.Vector3 a, vm.Vector3 b) => (_px(a) - _px(b)).length;

void main() {
  group('DraftingConvention', () {
    const oriented = DimensionTextPlacement.oriented;
    const inlined = DimensionTextPlacement.inlined;
    const referencing = DimensionTextPlacement.referencing;
    final cases = [
      (DraftingConvention.isoOriented, DraftingStandard.iso, oriented),
      (DraftingConvention.isoReferencing, DraftingStandard.iso, referencing),
      (DraftingConvention.asmeInlined, DraftingStandard.asme, inlined),
      (DraftingConvention.asmeReferencing, DraftingStandard.asme, referencing),
    ];
    for (final (convention, standard, placement) in cases) {
      test('${convention.name} is ${standard.name}, ${placement.name}', () {
        expect(convention.standard, standard);
        expect(convention.placement, placement);
      });
    }
  });

  group('DimensionStyle', () {
    test('defaults come from the style tokens', () {
      const style = DimensionStyle();
      expect(style.lineWidth, StyleTokens.dimensionLineWidth);
      expect(
        style.witnessExtensionPixels,
        StyleTokens.dimensionWitnessExtensionPixels,
      );
      expect(style.offsetPixels, StyleTokens.dimensionOffsetPixels);
      expect(style.arrowLengthPixels, StyleTokens.dimensionArrowLengthPixels);
      expect(style.arrowWidthPixels, StyleTokens.dimensionArrowWidthPixels);
      expect(style.textPixelSize, StyleTokens.dimensionTextPixelSize);
      expect(style.textGapPixels, StyleTokens.dimensionTextGapPixels);
      expect(style.alignmentTolerance, StyleTokens.dimensionAlignmentTolerance);
      expect(style.leader, const LeaderLineStyle());
    });

    final gaps = [
      (const DimensionStyle(), DraftingStandard.iso, 2.0),
      (const DimensionStyle(), DraftingStandard.asme, 4.0),
      (const DimensionStyle(witnessGapPixels: 7), DraftingStandard.iso, 7.0),
      (const DimensionStyle(witnessGapPixels: 7), DraftingStandard.asme, 7.0),
    ];
    for (final (style, standard, gap) in gaps) {
      test('witness gap for $standard, override ${style.witnessGapPixels}', () {
        expect(style.witnessGapFor(standard), gap);
      });
    }

    test('the per-standard gaps are the tokens', () {
      expect(
        const DimensionStyle().witnessGapFor(DraftingStandard.iso),
        StyleTokens.dimensionWitnessGapIsoPixels,
      );
      expect(
        const DimensionStyle().witnessGapFor(DraftingStandard.asme),
        StyleTokens.dimensionWitnessGapAsmePixels,
      );
    });
  });

  group('what a dimension measures', () {
    final cases = [
      (
        name: 'one axis',
        to: vm.Vector3(100, 0, 0),
        multiAxis: MultiAxisDimension.components,
        style: const DimensionStyle(),
        texts: ['100 mm'],
      ),
      (
        name: 'one axis, negative direction',
        to: vm.Vector3(0, -30, 0),
        multiAxis: MultiAxisDimension.direct,
        style: const DimensionStyle(),
        texts: ['30 mm'],
      ),
      (
        name: 'off-axis noise within the tolerance',
        to: vm.Vector3(100, 0.05, 0),
        multiAxis: MultiAxisDimension.direct,
        style: const DimensionStyle(),
        texts: ['100 mm'],
      ),
      (
        name: 'off-axis offset past the tolerance, components',
        to: vm.Vector3(100, 0.2, 0),
        multiAxis: MultiAxisDimension.components,
        style: const DimensionStyle(),
        texts: ['100 mm', '0.2 mm'],
      ),
      (
        name: 'a wider tolerance the app sets',
        to: vm.Vector3(100, 0.2, 0),
        multiAxis: MultiAxisDimension.components,
        style: const DimensionStyle(alignmentTolerance: 0.01),
        texts: ['100 mm'],
      ),
      (
        name: 'two axes, components',
        to: vm.Vector3(30, 40, 0),
        multiAxis: MultiAxisDimension.components,
        style: const DimensionStyle(),
        texts: ['30 mm', '40 mm'],
      ),
      (
        name: 'two axes, direct',
        to: vm.Vector3(30, 40, 0),
        multiAxis: MultiAxisDimension.direct,
        style: const DimensionStyle(),
        texts: ['50 mm'],
      ),
      (
        name: 'three axes, components in X, Y, Z order',
        to: vm.Vector3(-3, 4, -12),
        multiAxis: MultiAxisDimension.components,
        style: const DimensionStyle(),
        texts: ['3 mm', '4 mm', '12 mm'],
      ),
      (
        name: 'three axes, direct',
        to: vm.Vector3(-3, 4, -12),
        multiAxis: MultiAxisDimension.direct,
        style: const DimensionStyle(),
        texts: ['13 mm'],
      ),
    ];
    for (final c in cases) {
      test(c.name, () {
        final primitives = _dimension(
          vm.Vector3.zero(),
          c.to,
          multiAxis: c.multiAxis,
          style: c.style,
          convention: DraftingConvention.isoReferencing,
        );
        expect(textsOf(primitives), c.texts);
      });
    }

    test('component labels form one set and share a unit', () {
      final primitives = _dimension(
        vm.Vector3.zero(),
        vm.Vector3(12000, 500, 0),
        convention: DraftingConvention.isoReferencing,
      );
      expect(textsOf(primitives), ['12 m', '0.5 m']);
    });

    test('coincident points have no dimension', () {
      expect(_dimension(vm.Vector3(1, 2, 3), vm.Vector3(1, 2, 3)), isEmpty);
    });

    test('a point behind the camera hides the dimension', () {
      expect(_dimension(vm.Vector3.zero(), vm.Vector3(0, 0, 500)), isEmpty);
    });
  });

  group('labels', () {
    final cases = [
      (
        name: 'inches in a metric format',
        worldUnits: UnitSystem.imperial,
        format: DisplayFormat.metric,
        length: 1.0,
        numbers: const NumberFormatting(),
        text: '25.4 mm',
      ),
      (
        name: 'metric promotes to meters',
        worldUnits: UnitSystem.metric,
        format: DisplayFormat.metric,
        length: 12500.0,
        numbers: const NumberFormatting(),
        text: '12.5 m',
      ),
      (
        name: 'millimeters in fractional inch',
        worldUnits: UnitSystem.metric,
        format: DisplayFormat.fractionalInch,
        length: 1028.7,
        numbers: const NumberFormatting(),
        text: '3\' 4 1/2"',
      ),
      (
        name: 'decimal inch with a comma and no leading zero',
        worldUnits: UnitSystem.imperial,
        format: DisplayFormat.decimalInch,
        length: 0.125,
        numbers: const NumberFormatting(
          decimalMarker: DecimalMarker.comma,
          showLeadingZero: false,
        ),
        text: ',125 in',
      ),
    ];
    for (final c in cases) {
      test(c.name, () {
        final primitives = _dimension(
          vm.Vector3.zero(),
          vm.Vector3(c.length, 0, 0),
          worldUnits: c.worldUnits,
          format: c.format,
          numbers: c.numbers,
        );
        expect(textsOf(primitives), [c.text]);
        expect(
          (billboardsOf(primitives).single.content.value! as TextRequest)
              .heightPixels,
          StyleTokens.dimensionTextPixelSize,
        );
      });
    }
  });

  group('witness lines', () {
    final measured = [
      (name: 'X', to: vm.Vector3(100, 0, 0), axis: vm.Vector3(1, 0, 0)),
      (name: 'Y', to: vm.Vector3(0, 80, 0), axis: vm.Vector3(0, 1, 0)),
      (name: 'Z', to: vm.Vector3(0, 0, -60), axis: vm.Vector3(0, 0, 1)),
      (
        name: 'X with a Y offset',
        to: vm.Vector3(100, 30, 0),
        axis: vm.Vector3(1, 0, 0),
      ),
    ];
    for (final c in measured) {
      test('are perpendicular to the measured axis, ${c.name}', () {
        final oblique = CameraBasis.lookAt(
          position: vm.Vector3(300, -250, 200),
          target: vm.Vector3(20, 10, -10),
          convention: _zUp,
        );
        final primitives = _dimension(vm.Vector3.zero(), c.to, camera: oblique);
        final [witnessFrom, witnessTo, ...] = linesOf(primitives);
        for (final w in [witnessFrom, witnessTo]) {
          expect((w.end - w.start).normalized().dot(c.axis), closeTo(0, 1e-9));
        }
      });
    }

    final standards = [
      (
        DraftingConvention.isoOriented,
        StyleTokens.dimensionWitnessGapIsoPixels,
      ),
      (
        DraftingConvention.asmeInlined,
        StyleTokens.dimensionWitnessGapAsmePixels,
      ),
    ];
    for (final (convention, gap) in standards) {
      test('leave the ${convention.standard.name} gap and overshoot', () {
        final from = vm.Vector3.zero();
        final to = vm.Vector3(100, 0, 0);
        final primitives = _dimension(from, to, convention: convention);
        final [witnessFrom, witnessTo, ...] = linesOf(primitives);
        expect(_pxLength(from, witnessFrom.start), closeTo(gap, 1e-9));
        expect(_pxLength(to, witnessTo.start), closeTo(gap, 1e-9));
        expect(
          _pxLength(from, witnessFrom.end),
          closeTo(
            StyleTokens.dimensionOffsetPixels +
                StyleTokens.dimensionWitnessExtensionPixels,
            1e-9,
          ),
        );
      });
    }

    test('take the app\'s offset direction', () {
      final primitives = _dimension(
        vm.Vector3.zero(),
        vm.Vector3(100, 0, 0),
        offsetDirection: vm.Vector3(0.5, -1, 0),
      );
      final [witnessFrom, ...] = linesOf(primitives);
      expectVector3(
        (witnessFrom.end - witnessFrom.start).normalized(),
        vm.Vector3(0, -1, 0),
        'witness direction',
      );
    });

    test('point up on screen by default', () {
      final primitives = _dimension(vm.Vector3.zero(), vm.Vector3(100, 0, 0));
      final [witnessFrom, ...] = linesOf(primitives);
      expectVector3(
        (witnessFrom.end - witnessFrom.start).normalized(),
        vm.Vector3(0, 1, 0),
        'witness direction',
      );
    });
  });

  group('arrowheads', () {
    test('sit inside the witness lines at their pixel size', () {
      final from = vm.Vector3.zero();
      final to = vm.Vector3(100, 0, 0);
      final primitives = _dimension(from, to);
      final lines = linesOf(primitives);
      final dimensionLine = lines[2];
      final arrows = lines.sublist(3, 7);
      for (final (i, tip) in [dimensionLine.start, dimensionLine.end].indexed) {
        final [a, b] = arrows.sublist(2 * i, 2 * i + 2);
        expectVector3(a.start, tip, 'arrow $i tip');
        expectVector3(b.start, tip, 'arrow $i tip');
        final base = (a.end + b.end) / 2;
        expect(
          _pxLength(tip, base),
          closeTo(StyleTokens.dimensionArrowLengthPixels, 1e-9),
        );
        expect(
          _pxLength(a.end, b.end),
          closeTo(StyleTokens.dimensionArrowWidthPixels, 1e-9),
        );
        // The base lies between the tips, toward the other end.
        final inward = i == 0 ? 1.0 : -1.0;
        expect((base - tip).x * inward, greaterThan(0));
      }
      for (final line in lines) {
        expect(line.widthPixels, StyleTokens.dimensionLineWidth);
      }
    });
  });

  group('text placement', () {
    final from = vm.Vector3.zero();
    final long = vm.Vector3(100, 0, 0);
    final short = vm.Vector3(10, 0, 0);

    test('ISO oriented sits above the line, parallel and upright', () {
      final primitives = _dimension(from, long);
      final label = billboardsOf(primitives).single;
      final orientation = label.orientation as CoplanarOrientation;
      expectVector3(orientation.normal, _topView.toViewer, 'normal');
      expectVector3(orientation.right, vm.Vector3(1, 0, 0), 'right');
      expect(label.alignment.storage, [0.5, 0.0]);
      expect(label.offset!.pixels, StyleTokens.dimensionTextGapPixels);
      expectVector3(label.offset!.direction, vm.Vector3(0, 1, 0), 'up');
      // The text lifts off the line along its own vertical axis.
      expectVector3(
        _zUp.cross(orientation.normal, orientation.right),
        label.offset!.direction,
        'text up',
      );
      expect(linesOf(primitives), hasLength(7));
    });

    final upright = [
      (name: 'right to left', to: vm.Vector3(-100, 0, 0), right: [1, 0, 0]),
      (name: 'vertical', to: vm.Vector3(0, -100, 0), right: [0, 1, 0]),
    ];
    for (final c in upright) {
      test('ISO oriented text stays upright, ${c.name}', () {
        final label = billboardsOf(_dimension(from, c.to)).single;
        final orientation = label.orientation as CoplanarOrientation;
        expectVector3(
          orientation.right,
          vm.Vector3.array([for (final v in c.right) v.toDouble()]),
          'right',
        );
      });
    }

    test('ASME inlined breaks the line around horizontal text', () {
      final primitives = _dimension(
        from,
        long,
        convention: DraftingConvention.asmeInlined,
      );
      final label = billboardsOf(primitives).single;
      expect(label.orientation, isA<ViewerFacingOrientation>());
      expect(label.alignment.storage, [0.5, 0.5]);
      expect(label.offset, isNull);
      final lines = linesOf(primitives);
      expect(lines, hasLength(8));
      final [_, _, first, second, ...] = lines;
      expectVector3(label.anchor, (first.start + second.end) / 2, 'center');
      expect(
        _pxLength(first.end, second.start),
        closeTo(
          label.content.widthPixels + 2 * StyleTokens.dimensionTextGapPixels,
          1e-9,
        ),
      );
    });

    for (final convention in [
      DraftingConvention.isoReferencing,
      DraftingConvention.asmeReferencing,
    ]) {
      test('${convention.name} leads the text off the line', () {
        final primitives = _dimension(from, long, convention: convention);
        final lines = linesOf(primitives);
        expect(lines, hasLength(9));
        final label = billboardsOf(primitives).single;
        expect(label.orientation, isA<ViewerFacingOrientation>());
        final dimensionLine = lines[2];
        final leader = lines[7];
        expectVector3(
          leader.start,
          computeCalloutLeaderGeometry(
            anchor: (dimensionLine.start + dimensionLine.end) / 2,
            cameraRight: _topView.right,
            cameraUp: _topView.up,
            worldUnitsPerPixel: ScreenSpaceUtils.worldUnitsPerPixelAt(
              from,
              _topView,
              _fovRadians,
              _viewport.y,
            )!,
            quadrant: CalloutQuadrant.topRight,
          ).gapEnd,
          'leader start',
        );
        expect(label.alignment.storage, [0.0, 0.5]);
      });
    }

    for (final convention in [
      DraftingConvention.isoOriented,
      DraftingConvention.asmeInlined,
    ]) {
      test('${convention.name} falls back to referencing when cramped', () {
        final primitives = _dimension(from, short, convention: convention);
        expect(linesOf(primitives), hasLength(9));
        expect(
          billboardsOf(primitives).single.orientation,
          isA<ViewerFacingOrientation>(),
        );
      });
    }

    final quadrants = [
      (
        name: 'horizontal line, outer side up',
        to: vm.Vector3(100, 0, 0),
        offset: null,
        quadrant: CalloutQuadrant.topRight,
      ),
      (
        name: 'horizontal line, outer side down',
        to: vm.Vector3(100, 0, 0),
        offset: vm.Vector3(0, -1, 0),
        quadrant: CalloutQuadrant.bottomRight,
      ),
      (
        name: 'line at the leader angle',
        to: vm.Vector3(
          100 * math.cos(math.pi / 6),
          100 * math.sin(math.pi / 6),
          0,
        ),
        offset: null,
        quadrant: CalloutQuadrant.topLeft,
      ),
    ];
    for (final c in quadrants) {
      test('a referencing leader avoids the line, ${c.name}', () {
        final primitives = _dimension(
          from,
          c.to,
          convention: DraftingConvention.isoReferencing,
          multiAxis: MultiAxisDimension.direct,
          offsetDirection: c.offset,
        );
        expect(
          billboardsOf(primitives).single.alignment.storage,
          calloutAnchorAlignment(c.quadrant).storage,
        );
        final lines = linesOf(primitives);
        final dimensionLine = lines[2];
        final [angled, _] = lines.sublist(7);
        final expected = computeCalloutLeaderGeometry(
          anchor: (dimensionLine.start + dimensionLine.end) / 2,
          cameraRight: _topView.right,
          cameraUp: _topView.up,
          worldUnitsPerPixel: ScreenSpaceUtils.worldUnitsPerPixelAt(
            from,
            _topView,
            _fovRadians,
            _viewport.y,
          )!,
          quadrant: c.quadrant,
        );
        expectVector3(angled.end, expected.elbow, 'elbow');
      });
    }
  });

  test('every primitive carries the key and opacity', () {
    final primitives = _dimension(
      vm.Vector3.zero(),
      vm.Vector3(30, 40, 5),
      convention: DraftingConvention.asmeReferencing,
      key: #dimension,
      opacity: 0.4,
    );
    expect(primitives, isNotEmpty);
    for (final p in primitives) {
      expect(p.key, #dimension);
      expect(p.opacity, 0.4);
    }
  });
}
