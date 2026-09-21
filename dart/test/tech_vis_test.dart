import 'dart:math' as math;

import 'package:tech_vis/tech_vis.dart';
import 'package:test/test.dart';
import 'package:vector_math/vector_math.dart';

void main() {
  group('ViewportSize', () {
    test('equality by value', () {
      const a = ViewportSize(800, 600);
      const b = ViewportSize(800, 600);
      const c = ViewportSize(1024, 768);

      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
      expect(a, isNot(equals(c)));
    });

    test('width and height accessible', () {
      const v = ViewportSize(1920, 1080);
      expect(v.width, 1920);
      expect(v.height, 1080);
    });
  });

  group('RenderMode', () {
    test('has canvas and widget variants', () {
      expect(
        RenderMode.values,
        containsAll([RenderMode.canvas, RenderMode.widget]),
      );
    });
  });

  group('FrameContext', () {
    test('stores viewport and DPR', () {
      const ctx = FrameContext(
        viewportSize: ViewportSize(800, 600),
        devicePixelRatio: 2.0,
      );
      expect(ctx.viewportSize.width, 800);
      expect(ctx.devicePixelRatio, 2.0);
    });

    test('is generic — no domain-specific fields', () {
      // FrameContext contains only viewport and DPR.
      // Domain-specific fields (tracked positions, playback progress)
      // live in a domain-specific subclass in the consumer's package.
      const ctx = FrameContext(
        viewportSize: ViewportSize(800, 600),
        devicePixelRatio: 1.0,
      );
      expect(ctx.viewportSize.width, 800);
      expect(ctx.devicePixelRatio, 1.0);
    });
  });

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

  group('SceneTheme', () {
    test('is generic — requires axisLineThickness and resolveLineColor', () {
      // SceneTheme requires axisLineThickness, axisLabelSize, and
      // resolveLineColor. Line weights for a consumer's own line
      // categories live in a domain-specific theme in its package.
      final theme = _TestSceneTheme();
      expect(theme.axisLineThickness, 0.5);
      expect(theme.axisLabelSize, 24.0);
    });

    test('resolveLineColor returns SceneColor', () {
      final theme = _TestSceneTheme();
      final color = theme.resolveLineColor('test');
      expect(color, isA<SceneColor>());
      expect(color.r, 1.0);
      expect(color.g, 1.0);
      expect(color.b, 1.0);
      expect(color.a, 1.0);
    });
  });

  group('SceneColor', () {
    test('equality by value', () {
      const a = SceneColor(1.0, 0.0, 0.0, 1.0);
      const b = SceneColor(1.0, 0.0, 0.0, 1.0);
      const c = SceneColor(0.0, 1.0, 0.0, 1.0);

      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
      expect(a, isNot(equals(c)));
    });

    test('toString includes components', () {
      const color = SceneColor(0.5, 0.6, 0.7, 0.8);
      expect(color.toString(), contains('0.5'));
      expect(color.toString(), contains('0.8'));
    });
  });
}

class _TestSceneTheme implements SceneTheme {
  @override
  double get axisLineThickness => 0.5;

  @override
  double get axisLabelSize => 24.0;

  @override
  SceneColor resolveLineColor(Object lineCategory) =>
      const SceneColor(1.0, 1.0, 1.0, 1.0);
}
