import 'package:tech_vis/tech_vis.dart';
import 'package:test/test.dart';
import 'package:vector_math/vector_math_64.dart' as vm;

import 'support/vectors.dart';

typedef _Defaults = ({
  ViewportOverlayKind kind,
  double corner,
  double offsetX,
  double offsetY,
  double width,
  double height,
});

const _defaults = <_Defaults>[
  (
    kind: ViewportOverlayKind.scaleBar,
    corner: StyleTokens.scaleBarCorner,
    offsetX: StyleTokens.scaleBarOffsetXPixels,
    offsetY: StyleTokens.scaleBarOffsetYPixels,
    width: StyleTokens.scaleBarWidthPixels,
    height: StyleTokens.scaleBarHeightPixels,
  ),
  (
    kind: ViewportOverlayKind.colorRampLegend,
    corner: StyleTokens.colorRampLegendCorner,
    offsetX: StyleTokens.colorRampLegendOffsetXPixels,
    offsetY: StyleTokens.colorRampLegendOffsetYPixels,
    width: StyleTokens.colorRampLegendWidthPixels,
    height: StyleTokens.colorRampLegendHeightPixels,
  ),
  (
    kind: ViewportOverlayKind.navigationCube,
    corner: StyleTokens.navigationCubeCorner,
    offsetX: StyleTokens.navigationCubeOffsetXPixels,
    offsetY: StyleTokens.navigationCubeOffsetYPixels,
    width: StyleTokens.navigationCubeWidthPixels,
    height: StyleTokens.navigationCubeHeightPixels,
  ),
];

/// A corner other than [corner], so an override is observable.
ViewportCorner _otherCorner(ViewportCorner corner) =>
    ViewportCorner.values[(corner.index + 1) % ViewportCorner.values.length];

void main() {
  group('ViewportCorner', () {
    test('every corner round-trips through its token code', () {
      for (final corner in ViewportCorner.values) {
        expect(ViewportCorner.fromToken(corner.tokenCode), corner);
      }
    });

    test('codes match the documented order', () {
      expect(ViewportCorner.fromToken(0), ViewportCorner.topLeft);
      expect(ViewportCorner.fromToken(1), ViewportCorner.topRight);
      expect(ViewportCorner.fromToken(2), ViewportCorner.bottomLeft);
      expect(ViewportCorner.fromToken(3), ViewportCorner.bottomRight);
    });

    for (final code in const [-1.0, 0.5, 4.0, double.nan]) {
      test('rejects code $code', () {
        expect(() => ViewportCorner.fromToken(code), throwsArgumentError);
      });
    }
  });

  group('ViewportOverlayPlacement.of', () {
    for (final d in _defaults) {
      group(d.kind.name, () {
        final defaults = ViewportOverlayPlacement.of(d.kind);

        test('takes every value from the tokens without overrides', () {
          expect(defaults.corner, ViewportCorner.fromToken(d.corner));
          expect(defaults.offsetXPixels, d.offsetX);
          expect(defaults.offsetYPixels, d.offsetY);
          expect(defaults.widthPixels, d.width);
          expect(defaults.heightPixels, d.height);
        });

        final overrides = <String, ViewportOverlayPlacement>{
          'corner': ViewportOverlayPlacement.of(
            d.kind,
            corner: _otherCorner(defaults.corner),
          ),
          'offsetXPixels': ViewportOverlayPlacement.of(
            d.kind,
            offsetXPixels: d.offsetX + 5,
          ),
          'offsetYPixels': ViewportOverlayPlacement.of(
            d.kind,
            offsetYPixels: d.offsetY + 5,
          ),
          'widthPixels': ViewportOverlayPlacement.of(
            d.kind,
            widthPixels: d.width + 5,
          ),
          'heightPixels': ViewportOverlayPlacement.of(
            d.kind,
            heightPixels: d.height + 5,
          ),
        };

        for (final MapEntry(key: field, value: placement)
            in overrides.entries) {
          test('overriding $field changes only $field', () {
            final changed = {
              if (placement.corner != defaults.corner) 'corner',
              if (placement.offsetXPixels != defaults.offsetXPixels)
                'offsetXPixels',
              if (placement.offsetYPixels != defaults.offsetYPixels)
                'offsetYPixels',
              if (placement.widthPixels != defaults.widthPixels) 'widthPixels',
              if (placement.heightPixels != defaults.heightPixels)
                'heightPixels',
            };
            expect(changed, {field});
          });
        }
      });
    }

    test('gives each overlay kind its own corner', () {
      final corners = {
        for (final kind in ViewportOverlayKind.values)
          ViewportOverlayPlacement.of(kind).corner,
      };
      expect(corners, hasLength(ViewportOverlayKind.values.length));
    });
  });

  group('ViewportOverlayPlacement.rect', () {
    final viewport = vm.Vector2(1280, 720);
    const cases = <(ViewportCorner, List<double>)>[
      (ViewportCorner.topLeft, [10, 20, 110, 70]),
      (ViewportCorner.topRight, [1170, 20, 1270, 70]),
      (ViewportCorner.bottomLeft, [10, 650, 110, 700]),
      (ViewportCorner.bottomRight, [1170, 650, 1270, 700]),
    ];
    for (final (corner, expected) in cases) {
      test('offsets toward the center from ${corner.name}', () {
        final rect = ViewportOverlayPlacement(
          corner: corner,
          offsetXPixels: 10,
          offsetYPixels: 20,
          widthPixels: 100,
          heightPixels: 50,
        ).rect(viewport);
        expectNumbers(
          [rect.left, rect.top, rect.right, rect.bottom],
          expected,
          corner.name,
        );
      });
    }
  });

  test('placements with equal values are equal', () {
    expect(
      ViewportOverlayPlacement.of(ViewportOverlayKind.scaleBar),
      ViewportOverlayPlacement.of(ViewportOverlayKind.scaleBar),
    );
    expect(
      ViewportOverlayPlacement.of(ViewportOverlayKind.scaleBar).hashCode,
      ViewportOverlayPlacement.of(ViewportOverlayKind.scaleBar).hashCode,
    );
  });
}
