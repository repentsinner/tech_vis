import 'dart:math' as math;

import 'package:tech_vis/tech_vis.dart';
import 'package:test/test.dart';
import 'package:vector_math/vector_math_64.dart';

void main() {
  group('ScreenSpaceUtils', () {
    test('pixelToNDC maps pixel size to NDC range', () {
      // Half the viewport height → NDC 1.0
      final ndc = ScreenSpaceUtils.pixelToNDC(540, Vector2(1920, 1080));
      expect(ndc, closeTo(1.0, 1e-10));
    });

    test('pixelToNDC zero returns zero', () {
      final ndc = ScreenSpaceUtils.pixelToNDC(0, Vector2(1920, 1080));
      expect(ndc, 0.0);
    });

    test('calculateCameraDistance returns Euclidean distance', () {
      final a = Vector3(0, 0, 0);
      final b = Vector3(3, 4, 0);
      expect(
        ScreenSpaceUtils.calculateCameraDistance(a, b),
        closeTo(5.0, 1e-10),
      );
    });

    test('pixelSizeToWorldSize scales with distance and FOV', () {
      const fov = math.pi / 4; // 45°
      const distance = 100.0;
      const pixelSize = 10.0;
      final screen = Vector2(800, 600);

      final worldSize = ScreenSpaceUtils.pixelSizeToWorldSize(
        pixelSize,
        distance,
        fov,
        screen,
      );

      // worldSize = pixelSize * (2 * distance * tan(fov/2)) / height
      final expected = pixelSize * (2.0 * distance * math.tan(fov / 2.0)) / 600;
      expect(worldSize, closeTo(expected, 1e-10));
    });

    test('pixelSizeToWorldSize doubles when distance doubles', () {
      const fov = math.pi / 3;
      final screen = Vector2(1920, 1080);

      final near = ScreenSpaceUtils.pixelSizeToWorldSize(10, 100, fov, screen);
      final far = ScreenSpaceUtils.pixelSizeToWorldSize(10, 200, fov, screen);

      expect(far / near, closeTo(2.0, 1e-10));
    });
  });

  group('SceneLayoutConstants', () {
    test('axis length is positive', () {
      expect(SceneLayoutConstants.axisLength, greaterThan(0));
    });

    test('callout opacity bounds are ordered', () {
      expect(
        SceneLayoutConstants.calloutOpacityMin,
        lessThan(SceneLayoutConstants.calloutOpacityMax),
      );
      expect(
        SceneLayoutConstants.calloutOpacityNearDistance,
        lessThan(SceneLayoutConstants.calloutOpacityFarDistance),
      );
    });

    test('callout leader line width is positive', () {
      expect(SceneLayoutConstants.calloutLeaderLineWidth, greaterThan(0));
    });

    test('contains only generic constants — no domain-specific members', () {
      // Verify axis settings exist
      expect(SceneLayoutConstants.defaultAxisLineThickness, greaterThan(0));
      expect(SceneLayoutConstants.defaultAxisLabelSize, greaterThan(0));
      // Verify callout settings exist
      expect(SceneLayoutConstants.calloutGapPixels, greaterThan(0));
      expect(SceneLayoutConstants.calloutAngledLengthPixels, greaterThan(0));
      expect(SceneLayoutConstants.calloutLabelPixelSize, greaterThan(0));
    });
  });
}
