import 'package:tech_vis/tech_vis.dart';
import 'package:test/test.dart';
import 'package:vector_math/vector_math_64.dart' as vm;

import 'support/fake_text_resolver.dart';

void main() {
  group('LeaderLineStyle', () {
    test('default values from SceneLayoutConstants', () {
      const style = LeaderLineStyle();
      expect(style.lineWidth, SceneLayoutConstants.calloutLeaderLineWidth);
      expect(style.gapPixels, SceneLayoutConstants.calloutGapPixels);
      expect(
        style.angledLengthPixels,
        SceneLayoutConstants.calloutAngledLengthPixels,
      );
      expect(
        style.horizontalLengthPixels,
        SceneLayoutConstants.calloutHorizontalLengthPixels,
      );
      expect(style.angleDegrees, SceneLayoutConstants.calloutAngleDegrees);
    });

    test('custom values are stored', () {
      const style = LeaderLineStyle(
        lineWidth: 2.0,
        gapPixels: 8.0,
        angledLengthPixels: 40.0,
        horizontalLengthPixels: 30.0,
        angleDegrees: 45.0,
      );
      expect(style.lineWidth, 2.0);
      expect(style.gapPixels, 8.0);
      expect(style.angledLengthPixels, 40.0);
      expect(style.horizontalLengthPixels, 30.0);
      expect(style.angleDegrees, 45.0);
    });

    test('equality by value', () {
      const a = LeaderLineStyle(lineWidth: 1.5, gapPixels: 6.0);
      const b = LeaderLineStyle(lineWidth: 1.5, gapPixels: 6.0);
      const c = LeaderLineStyle(lineWidth: 2.0, gapPixels: 6.0);
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
      expect(a, isNot(equals(c)));
    });
  });

  group('computeCalloutLeaderGeometry', () {
    // Common test parameters: identity camera basis, 1:1 pixel mapping.
    final anchor = vm.Vector3.zero();
    final cameraRight = vm.Vector3(1, 0, 0);
    final cameraUp = vm.Vector3(0, 1, 0);
    const worldUnitsPerPixel = 1.0;

    test('uses default style when none provided', () {
      final result = computeCalloutLeaderGeometry(
        anchor: anchor,
        cameraRight: cameraRight,
        cameraUp: cameraUp,
        worldUnitsPerPixel: worldUnitsPerPixel,
        quadrant: CalloutQuadrant.topRight,
      );

      final totalHorizontal = result.labelEdge.x - result.gapEnd.x;
      expect(
        totalHorizontal,
        greaterThan(0),
        reason: 'topRight quadrant extends rightward',
      );
      expect(result.labelEdge.x, greaterThan(result.elbow.x));
    });

    test('custom style overrides default segment lengths', () {
      final defaultResult = computeCalloutLeaderGeometry(
        anchor: anchor,
        cameraRight: cameraRight,
        cameraUp: cameraUp,
        worldUnitsPerPixel: worldUnitsPerPixel,
        quadrant: CalloutQuadrant.topRight,
      );

      final shorterResult = computeCalloutLeaderGeometry(
        anchor: anchor,
        cameraRight: cameraRight,
        cameraUp: cameraUp,
        worldUnitsPerPixel: worldUnitsPerPixel,
        quadrant: CalloutQuadrant.topRight,
        style: const LeaderLineStyle(angledLengthPixels: 10.0),
      );

      final defaultAngledLen =
          (defaultResult.elbow - defaultResult.gapEnd).length;
      final shorterAngledLen =
          (shorterResult.elbow - shorterResult.gapEnd).length;

      expect(shorterAngledLen, lessThan(defaultAngledLen));
    });

    test('custom horizontalLengthPixels overrides default', () {
      final defaultResult = computeCalloutLeaderGeometry(
        anchor: anchor,
        cameraRight: cameraRight,
        cameraUp: cameraUp,
        worldUnitsPerPixel: worldUnitsPerPixel,
        quadrant: CalloutQuadrant.topRight,
      );

      final shorterResult = computeCalloutLeaderGeometry(
        anchor: anchor,
        cameraRight: cameraRight,
        cameraUp: cameraUp,
        worldUnitsPerPixel: worldUnitsPerPixel,
        quadrant: CalloutQuadrant.topRight,
        style: const LeaderLineStyle(horizontalLengthPixels: 5.0),
      );

      final defaultHorizLen =
          (defaultResult.labelEdge - defaultResult.elbow).length;
      final shorterHorizLen =
          (shorterResult.labelEdge - shorterResult.elbow).length;

      expect(shorterHorizLen, lessThan(defaultHorizLen));
    });

    test('topLeft quadrant extends leftward', () {
      final result = computeCalloutLeaderGeometry(
        anchor: anchor,
        cameraRight: cameraRight,
        cameraUp: cameraUp,
        worldUnitsPerPixel: worldUnitsPerPixel,
        quadrant: CalloutQuadrant.topLeft,
      );

      expect(result.labelEdge.x, lessThan(0), reason: 'topLeft extends left');
      expect(
        result.labelEdge.y,
        greaterThan(0),
        reason: 'topLeft extends upward (positive cameraUp)',
      );
    });

    test('bottomRight quadrant extends rightward and downward', () {
      final result = computeCalloutLeaderGeometry(
        anchor: anchor,
        cameraRight: cameraRight,
        cameraUp: cameraUp,
        worldUnitsPerPixel: worldUnitsPerPixel,
        quadrant: CalloutQuadrant.bottomRight,
      );

      expect(result.labelEdge.x, greaterThan(0));
      expect(
        result.labelEdge.y,
        lessThan(0),
        reason: 'bottomRight extends downward (negative cameraUp)',
      );
    });

    test('bottomLeft quadrant extends leftward and downward', () {
      final result = computeCalloutLeaderGeometry(
        anchor: anchor,
        cameraRight: cameraRight,
        cameraUp: cameraUp,
        worldUnitsPerPixel: worldUnitsPerPixel,
        quadrant: CalloutQuadrant.bottomLeft,
      );

      expect(result.labelEdge.x, lessThan(0));
      expect(result.labelEdge.y, lessThan(0));
    });
  });

  group('calloutAnchorAlignment', () {
    test('right quadrants anchor at left edge', () {
      expect(
        calloutAnchorAlignment(CalloutQuadrant.topRight),
        vm.Vector2(0.0, 0.5),
      );
      expect(
        calloutAnchorAlignment(CalloutQuadrant.bottomRight),
        vm.Vector2(0.0, 0.5),
      );
    });

    test('left quadrants anchor at right edge', () {
      expect(
        calloutAnchorAlignment(CalloutQuadrant.topLeft),
        vm.Vector2(1.0, 0.5),
      );
      expect(
        calloutAnchorAlignment(CalloutQuadrant.bottomLeft),
        vm.Vector2(1.0, 0.5),
      );
    });
  });

  group('createCalloutLabel', () {
    final cases = <(CalloutQuadrant, vm.Vector2)>[
      (CalloutQuadrant.topRight, vm.Vector2(0, 0.5)),
      (CalloutQuadrant.bottomRight, vm.Vector2(0, 0.5)),
      (CalloutQuadrant.topLeft, vm.Vector2(1, 0.5)),
      (CalloutQuadrant.bottomLeft, vm.Vector2(1, 0.5)),
    ];
    for (final (quadrant, alignment) in cases) {
      test('sets the label at the leader end, ${quadrant.name}', () {
        final leader = computeCalloutLeaderGeometry(
          anchor: vm.Vector3(1, 2, 3),
          cameraRight: vm.Vector3(1, 0, 0),
          cameraUp: vm.Vector3(0, 1, 0),
          worldUnitsPerPixel: 0.5,
          quadrant: quadrant,
        );
        final content = fakeTextResolver(
          const TextRequest(
            text: 'note',
            heightPixels: SceneLayoutConstants.calloutLabelPixelSize,
          ),
        );
        final label = createCalloutLabel(
          leader: leader,
          quadrant: quadrant,
          content: content,
          key: 'callout',
          opacity: 0.25,
        );
        expect(label.anchor, leader.labelEdge);
        expect(label.alignment, alignment);
        expect(label.orientation, isA<ViewerFacingOrientation>());
        expect(label.offset, isNull);
        expect(label.content, same(content));
        expect(label.key, 'callout');
        expect(label.opacity, 0.25);
      });
    }
  });

  group('createCalloutLeaderLines', () {
    test('draws the leader as its two segments at its own width', () {
      // A custom width the call below does not repeat, so the lines can
      // only take it from the leader.
      final leader = computeCalloutLeaderGeometry(
        anchor: vm.Vector3(1, 2, 3),
        cameraRight: vm.Vector3(1, 0, 0),
        cameraUp: vm.Vector3(0, 1, 0),
        worldUnitsPerPixel: 0.5,
        quadrant: CalloutQuadrant.topLeft,
        style: const LeaderLineStyle(lineWidth: 2),
      );
      final lines = createCalloutLeaderLines(
        leader: leader,
        key: 'callout',
        opacity: 0.25,
      );
      expect(lines, hasLength(2));
      expect(lines[0].start, leader.gapEnd);
      expect(lines[0].end, leader.elbow);
      expect(lines[1].start, leader.elbow);
      expect(lines[1].end, leader.labelEdge);
      for (final line in lines) {
        expect(line.widthPixels, 2);
        expect(line.key, 'callout');
        expect(line.opacity, 0.25);
      }
    });
  });

  group('computeCalloutOpacity', () {
    test('returns max opacity at near distance', () {
      expect(
        computeCalloutOpacity(SceneLayoutConstants.calloutOpacityNearDistance),
        SceneLayoutConstants.calloutOpacityMax,
      );
    });

    test('returns max opacity below near distance', () {
      expect(
        computeCalloutOpacity(10.0),
        SceneLayoutConstants.calloutOpacityMax,
      );
    });

    test('returns min opacity at far distance', () {
      expect(
        computeCalloutOpacity(SceneLayoutConstants.calloutOpacityFarDistance),
        SceneLayoutConstants.calloutOpacityMin,
      );
    });

    test('returns min opacity above far distance', () {
      expect(
        computeCalloutOpacity(1000.0),
        SceneLayoutConstants.calloutOpacityMin,
      );
    });

    test('midpoint distance returns average of max and min', () {
      const mid =
          (SceneLayoutConstants.calloutOpacityNearDistance +
              SceneLayoutConstants.calloutOpacityFarDistance) /
          2.0;
      const expected =
          (SceneLayoutConstants.calloutOpacityMax +
              SceneLayoutConstants.calloutOpacityMin) /
          2.0;
      expect(computeCalloutOpacity(mid), closeTo(expected, 0.001));
    });

    test('returns zero distance as max opacity', () {
      expect(
        computeCalloutOpacity(0.0),
        SceneLayoutConstants.calloutOpacityMax,
      );
    });
  });
}
