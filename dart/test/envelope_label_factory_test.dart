import 'package:tech_vis/tech_vis.dart';
import 'package:test/test.dart';
import 'package:vector_math/vector_math_64.dart' as vm;

import 'support/fake_text_resolver.dart';

const _tolerance = 1e-9;

Matcher _closeToVector(vm.Vector3 expected) => predicate<vm.Vector3>(
  (actual) => (actual - expected).length < _tolerance,
  'within $_tolerance of $expected',
);

const _zUpRight = CoordinateConvention(
  up: SpatialAxis.z,
  handedness: Handedness.right,
);
const _yUpRight = CoordinateConvention(
  up: SpatialAxis.y,
  handedness: Handedness.right,
);
const _zUpLeft = CoordinateConvention(
  up: SpatialAxis.z,
  handedness: Handedness.left,
);

/// Expected label frame of one convention: the up direction, the label's
/// text direction, and anchors on the top face of the shared box.
class _Case {
  const _Case({
    required this.convention,
    required this.up,
    required this.right,
    required this.corners,
    required this.cornerDirections,
    required this.edgeTabs,
  });

  final CoordinateConvention convention;
  final vm.Vector3 up;
  final vm.Vector3 right;
  final Map<LabelCorner, vm.Vector3> corners;
  final Map<LabelCorner, vm.Vector3> cornerDirections;
  final List<(LabelEdge, LabelAlignment, vm.Vector3, vm.Vector2)> edgeTabs;
}

void main() {
  final bounds = BoundingBox(
    minBounds: vm.Vector3(0, 0, 0),
    maxBounds: vm.Vector3(4, 2, 1),
  );

  // Z-up right-handed: top is z = 1, text runs along +X, front is -Y.
  // Y-up right-handed: top is y = 2, back is the fallback axis +X, and
  // text runs along +Z, so text direction cross back gives up.
  // Z-up left-handed: the mirrored hand rule turns text toward -X.
  final cases = [
    _Case(
      convention: _zUpRight,
      up: vm.Vector3(0, 0, 1),
      right: vm.Vector3(1, 0, 0),
      corners: {
        LabelCorner.topFrontLeft: vm.Vector3(0, 0, 1),
        LabelCorner.topFrontRight: vm.Vector3(4, 0, 1),
        LabelCorner.topBackLeft: vm.Vector3(0, 2, 1),
        LabelCorner.topBackRight: vm.Vector3(4, 2, 1),
      },
      cornerDirections: {
        LabelCorner.topFrontLeft: vm.Vector3(-1, -1, 1),
        LabelCorner.topFrontRight: vm.Vector3(1, -1, 1),
        LabelCorner.topBackLeft: vm.Vector3(-1, 1, 1),
        LabelCorner.topBackRight: vm.Vector3(1, 1, 1),
      },
      edgeTabs: [
        (
          LabelEdge.front,
          LabelAlignment.left,
          vm.Vector3(0, 0, 1),
          vm.Vector2(0, 1),
        ),
        (
          LabelEdge.front,
          LabelAlignment.center,
          vm.Vector3(2, 0, 1),
          vm.Vector2(0.5, 1),
        ),
        (
          LabelEdge.back,
          LabelAlignment.right,
          vm.Vector3(4, 2, 1),
          vm.Vector2(1, 0),
        ),
      ],
    ),
    _Case(
      convention: _yUpRight,
      up: vm.Vector3(0, 1, 0),
      right: vm.Vector3(0, 0, 1),
      corners: {
        LabelCorner.topFrontLeft: vm.Vector3(0, 2, 0),
        LabelCorner.topFrontRight: vm.Vector3(0, 2, 1),
        LabelCorner.topBackLeft: vm.Vector3(4, 2, 0),
        LabelCorner.topBackRight: vm.Vector3(4, 2, 1),
      },
      cornerDirections: {
        LabelCorner.topFrontLeft: vm.Vector3(-1, 1, -1),
        LabelCorner.topFrontRight: vm.Vector3(-1, 1, 1),
        LabelCorner.topBackLeft: vm.Vector3(1, 1, -1),
        LabelCorner.topBackRight: vm.Vector3(1, 1, 1),
      },
      edgeTabs: [
        (
          LabelEdge.front,
          LabelAlignment.left,
          vm.Vector3(0, 2, 0),
          vm.Vector2(0, 1),
        ),
        (
          LabelEdge.front,
          LabelAlignment.center,
          vm.Vector3(0, 2, 0.5),
          vm.Vector2(0.5, 1),
        ),
        (
          LabelEdge.back,
          LabelAlignment.right,
          vm.Vector3(4, 2, 1),
          vm.Vector2(1, 0),
        ),
      ],
    ),
    _Case(
      convention: _zUpLeft,
      up: vm.Vector3(0, 0, 1),
      right: vm.Vector3(-1, 0, 0),
      corners: {
        LabelCorner.topFrontLeft: vm.Vector3(4, 0, 1),
        LabelCorner.topFrontRight: vm.Vector3(0, 0, 1),
        LabelCorner.topBackLeft: vm.Vector3(4, 2, 1),
        LabelCorner.topBackRight: vm.Vector3(0, 2, 1),
      },
      cornerDirections: {
        LabelCorner.topFrontLeft: vm.Vector3(1, -1, 1),
        LabelCorner.topFrontRight: vm.Vector3(-1, -1, 1),
        LabelCorner.topBackLeft: vm.Vector3(1, 1, 1),
        LabelCorner.topBackRight: vm.Vector3(-1, 1, 1),
      },
      edgeTabs: [
        (
          LabelEdge.front,
          LabelAlignment.left,
          vm.Vector3(4, 0, 1),
          vm.Vector2(0, 1),
        ),
        (
          LabelEdge.front,
          LabelAlignment.center,
          vm.Vector3(2, 0, 1),
          vm.Vector2(0.5, 1),
        ),
        (
          LabelEdge.back,
          LabelAlignment.right,
          vm.Vector3(0, 2, 1),
          vm.Vector2(1, 0),
        ),
      ],
    ),
  ];

  group('EnvelopeLabelFactory.createEnvelopeLabel', () {
    for (final c in cases) {
      for (final corner in LabelCorner.values) {
        test('anchors a viewer-facing label at ${corner.name}, '
            '${c.convention}', () {
          final label = EnvelopeLabelFactory.createEnvelopeLabel(
            text: 'box',
            bounds: bounds,
            corner: corner,
            convention: c.convention,
            resolveText: fakeTextResolver,
            key: 'envelope',
          );
          expect(
            label.content.value,
            const TextRequest(
              text: 'box',
              heightPixels: EnvelopeLabelFactory.defaultPixelSize,
            ),
          );
          expect(
            label.content.widthPixels,
            3 * fakeCharacterAspect * EnvelopeLabelFactory.defaultPixelSize,
          );
          expect(label.key, 'envelope');
          expect(label.anchor, _closeToVector(c.corners[corner]!));
          expect(label.orientation, isA<ViewerFacingOrientation>());
          expect(
            label.offset!.direction,
            _closeToVector(c.cornerDirections[corner]!.normalized()),
          );
          expect(
            label.offset!.pixels,
            EnvelopeLabelFactory.defaultOffsetPixels,
          );
        });
      }
    }
  });

  group('EnvelopeLabelFactory.createCoplanarBillboardLabel', () {
    for (final c in cases) {
      test('lies on the top face by default, ${c.convention}', () {
        final label = EnvelopeLabelFactory.createCoplanarBillboardLabel(
          text: 'flat',
          position: vm.Vector3(1, 2, 3),
          convention: c.convention,
          resolveText: fakeTextResolver,
          key: 'envelope',
        );
        final orientation = label.orientation as CoplanarOrientation;
        expect(orientation.normal, _closeToVector(c.up));
        expect(orientation.right, _closeToVector(c.right));
        expect(label.alignment, vm.Vector2(0.5, 0.5));
      });
    }

    test('lies in the given plane, aligned as asked', () {
      final label = EnvelopeLabelFactory.createCoplanarBillboardLabel(
        text: 'flat',
        position: vm.Vector3(1, 2, 3),
        convention: _zUpRight,
        resolveText: fakeTextResolver,
        key: 'envelope',
        pixelSize: 12,
        surfaceNormal: vm.Vector3(0, 1, 0),
        textDirection: vm.Vector3(1, 0, 0),
        anchorAlignment: vm.Vector2(0, 1),
      );
      final orientation = label.orientation as CoplanarOrientation;
      expect(orientation.normal, vm.Vector3(0, 1, 0));
      expect(orientation.right, vm.Vector3(1, 0, 0));
      expect(label.anchor, vm.Vector3(1, 2, 3));
      expect(label.alignment, vm.Vector2(0, 1));
      expect(label.content.heightPixels, 12);
      expect(label.offset, isNull);
    });
  });

  group('EnvelopeLabelFactory.createEdgeTabLabel', () {
    for (final c in cases) {
      for (final (edge, alignment, anchor, anchorAlignment) in c.edgeTabs) {
        test('sets a tab on the ${edge.name} edge, ${alignment.name}, '
            '${c.convention}', () {
          final label = EnvelopeLabelFactory.createEdgeTabLabel(
            text: 'tab',
            bounds: bounds,
            edge: edge,
            alignment: alignment,
            convention: c.convention,
            resolveText: fakeTextResolver,
            key: 'envelope',
          );
          expect(label.anchor, _closeToVector(anchor));
          expect(label.alignment, anchorAlignment);
          final orientation = label.orientation as CoplanarOrientation;
          expect(orientation.normal, _closeToVector(c.up));
          expect(orientation.right, _closeToVector(c.right));
        });
      }
    }
  });
}
