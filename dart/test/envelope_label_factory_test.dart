import 'package:tech_vis/tech_vis.dart';
import 'package:test/test.dart';
import 'package:vector_math/vector_math_64.dart' as vm;

import 'support/fake_text_resolver.dart';

const _tolerance = 1e-9;

Matcher _closeToVector(vm.Vector3 expected) => predicate<vm.Vector3>(
  (actual) => (actual - expected).length < _tolerance,
  'within $_tolerance of $expected',
);

void main() {
  final bounds = BoundingBox(
    minBounds: vm.Vector3(0, 0, 0),
    maxBounds: vm.Vector3(4, 2, 1),
  );

  group('EnvelopeLabelFactory.createEnvelopeLabel', () {
    final cases = <(LabelCorner, vm.Vector3, vm.Vector3)>[
      (LabelCorner.topFrontLeft, vm.Vector3(0, 0, 1), vm.Vector3(-1, -1, 1)),
      (LabelCorner.topFrontRight, vm.Vector3(4, 0, 1), vm.Vector3(1, -1, 1)),
      (LabelCorner.topBackLeft, vm.Vector3(0, 2, 1), vm.Vector3(-1, 1, 1)),
      (LabelCorner.topBackRight, vm.Vector3(4, 2, 1), vm.Vector3(1, 1, 1)),
    ];
    for (final (corner, anchor, direction) in cases) {
      test('anchors a viewer-facing label at ${corner.name}', () {
        final label = EnvelopeLabelFactory.createEnvelopeLabel(
          text: 'box',
          bounds: bounds,
          corner: corner,
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
        expect(label.key, 'envelope');
        expect(label.anchor, _closeToVector(anchor));
        expect(label.orientation, isA<ViewerFacingOrientation>());
        expect(
          label.content.widthPixels,
          3 * fakeCharacterAspect * EnvelopeLabelFactory.defaultPixelSize,
        );
        expect(label.offset!.direction, _closeToVector(direction.normalized()));
        expect(label.offset!.pixels, EnvelopeLabelFactory.defaultOffsetPixels);
      });
    }
  });

  group('EnvelopeLabelFactory.createCoplanarBillboardLabel', () {
    test('lies in the given plane, aligned as asked', () {
      final label = EnvelopeLabelFactory.createCoplanarBillboardLabel(
        text: 'flat',
        position: vm.Vector3(1, 2, 3),
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
    final cases = <(LabelEdge, LabelAlignment, vm.Vector3, vm.Vector2)>[
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
    ];
    for (final (edge, alignment, anchor, anchorAlignment) in cases) {
      test('sets a tab on the ${edge.name} edge, ${alignment.name}', () {
        final label = EnvelopeLabelFactory.createEdgeTabLabel(
          text: 'tab',
          bounds: bounds,
          edge: edge,
          alignment: alignment,
          resolveText: fakeTextResolver,
          key: 'envelope',
        );
        expect(label.anchor, _closeToVector(anchor));
        expect(label.alignment, anchorAlignment);
        expect(label.orientation, isA<CoplanarOrientation>());
      });
    }
  });
}
