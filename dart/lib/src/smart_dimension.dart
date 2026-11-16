import 'dart:math' as math;

import 'package:vector_math/vector_math_64.dart' as vm;

import 'coordinate_frame.dart';
import 'leader_line.dart';
import 'primitives.dart';
import 'screen_space_utils.dart';
import 'style_tokens.g.dart';
import 'unit_system.dart';

/// Below this length, a vector is treated as zero.
const double _epsilon = 1e-9;

/// Alignment of oriented text: the middle of its bottom edge on the anchor.
final vm.Vector2 _bottomCenter = vm.Vector2(0.5, 0);

/// A drafting standard: the rules a dimension's look follows.
enum DraftingStandard {
  /// ISO 129.
  iso,

  /// ASME Y14.5.
  asme,
}

/// Where a dimension's text sits relative to its dimension line.
enum DimensionTextPlacement {
  /// Parallel to the dimension line, above it, turned to stay upright.
  oriented,

  /// Horizontal, in a break in the dimension line.
  inlined,

  /// Horizontal, on a reference line led off the dimension line.
  referencing,
}

/// A drafting standard and a style within it, which together decide where
/// a dimension's text sits and which way it reads.
///
/// The app selects one for a scene. It is independent of the display
/// format and of number formatting, so a metric scene may follow ASME.
enum DraftingConvention {
  /// ISO, with text parallel to the dimension line, above it, turned to
  /// stay upright.
  isoOriented(DraftingStandard.iso, DimensionTextPlacement.oriented),

  /// ISO, with horizontal text on a reference line led off the dimension
  /// line.
  isoReferencing(DraftingStandard.iso, DimensionTextPlacement.referencing),

  /// ASME, with horizontal text in a break in the dimension line.
  asmeInlined(DraftingStandard.asme, DimensionTextPlacement.inlined),

  /// ASME, with horizontal text on a reference line led off the dimension
  /// line.
  asmeReferencing(DraftingStandard.asme, DimensionTextPlacement.referencing);

  const DraftingConvention(this.standard, this.placement);

  /// The standard this convention belongs to.
  final DraftingStandard standard;

  /// Where this convention puts a dimension's text.
  ///
  /// Oriented and inlined text that does not fit between its witness
  /// lines on screen falls back to referencing, under the same standard.
  final DimensionTextPlacement placement;
}

/// What a dimension between points that differ along more than one axis
/// measures.
enum MultiAxisDimension {
  /// One dimension per axis along which the points differ.
  components,

  /// One dimension of the straight-line distance, its dimension line
  /// parallel to the segment between the points.
  direct,
}

/// Pixel sizes and the alignment tolerance of a dimension.
///
/// Every default is a style token.
class DimensionStyle {
  const DimensionStyle({
    this.lineWidth = StyleTokens.dimensionLineWidth,
    this.witnessGapPixels,
    this.witnessExtensionPixels = StyleTokens.dimensionWitnessExtensionPixels,
    this.offsetPixels = StyleTokens.dimensionOffsetPixels,
    this.arrowLengthPixels = StyleTokens.dimensionArrowLengthPixels,
    this.arrowWidthPixels = StyleTokens.dimensionArrowWidthPixels,
    this.textPixelSize = StyleTokens.dimensionTextPixelSize,
    this.textGapPixels = StyleTokens.dimensionTextGapPixels,
    this.alignmentTolerance = StyleTokens.dimensionAlignmentTolerance,
    this.leader = const LeaderLineStyle(),
  });

  /// Width of witness, dimension, and arrowhead lines in screen pixels.
  final double lineWidth;

  /// Gap between a measured point and the start of its witness line, or
  /// null for the standard's token.
  final double? witnessGapPixels;

  /// Length a witness line runs past the dimension line.
  final double witnessExtensionPixels;

  /// Distance from the measured points to the dimension line.
  final double offsetPixels;

  /// Length of an arrowhead along the dimension line.
  final double arrowLengthPixels;

  /// Width of an arrowhead across its barbs.
  final double arrowWidthPixels;

  /// Pixel height of the value text.
  final double textPixelSize;

  /// Gap between the text and the dimension line.
  final double textGapPixels;

  /// Largest offset along any other axis, as a fraction of the distance
  /// between the points, at which a dimension still measures one axis.
  final double alignmentTolerance;

  /// Leader of a referencing dimension, the same as a callout's.
  final LeaderLineStyle leader;

  /// Returns the witness line gap under [standard]: [witnessGapPixels]
  /// when set, else the standard's token.
  double witnessGapFor(DraftingStandard standard) =>
      witnessGapPixels ??
      switch (standard) {
        DraftingStandard.iso => StyleTokens.dimensionWitnessGapIsoPixels,
        DraftingStandard.asme => StyleTokens.dimensionWitnessGapAsmePixels,
      };
}

/// Factory for point-to-point dimensions between two points the app
/// supplies.
///
/// A dimension is camera-dependent, sized in screen pixels, so the app
/// rebuilds it each frame the camera moves.
class SmartDimensionFactory {
  /// Returns the primitives of a dimension from [from] to [to], seen by
  /// [camera] with vertical field of view [verticalFovRadians] in a
  /// [viewportSize] viewport.
  ///
  /// When the points differ along one world axis only, within
  /// [DimensionStyle.alignmentTolerance], the dimension measures that
  /// axis. Otherwise [multiAxis] decides between one dimension per
  /// varying axis, in X, Y, Z order, and one of the direct distance.
  ///
  /// Each dimension emits, in order: the witness lines from [from] and
  /// from [to], perpendicular to the measured direction; the dimension
  /// line, as two segments when inlined text breaks it; two lines per
  /// arrowhead, at the [from] end and then the [to] end; the two leader
  /// lines of a referencing dimension; and the text billboard.
  ///
  /// The dimension line sits [DimensionStyle.offsetPixels] from the
  /// points along [offsetDirection], less its component along the
  /// measured direction. Without one, it sits toward screen up, along
  /// the perpendicular that faces the viewer.
  ///
  /// The text is the measured length, converted from [worldUnits] and
  /// written by [format] with [numbers], and [resolveText] answers its
  /// request. [convention] places it. An oriented or inlined dimension
  /// whose text and arrowheads do not fit between its witness lines on
  /// screen falls back to its standard's referencing style.
  ///
  /// Returns an empty list for coincident points, or when a point the
  /// dimension needs lies on or behind the camera plane.
  static List<Primitive> create({
    required vm.Vector3 from,
    required vm.Vector3 to,
    required DraftingConvention convention,
    required DisplayFormat format,
    required UnitSystem worldUnits,
    required CameraBasis camera,
    required double verticalFovRadians,
    required vm.Vector2 viewportSize,
    required TextResolver resolveText,
    required Object? key,
    MultiAxisDimension multiAxis = MultiAxisDimension.components,
    vm.Vector3? offsetDirection,
    NumberFormatting numbers = const NumberFormatting(),
    DimensionStyle style = const DimensionStyle(),
    double opacity = 1.0,
  }) {
    final delta = to - from;
    final distance = delta.length;
    if (distance <= _epsilon) return const [];

    final varying = [
      for (final axis in SpatialAxis.values)
        if (delta[axis.index].abs() > style.alignmentTolerance * distance)
          axis.unitVector * delta[axis.index].sign,
    ];
    final directions =
        varying.length == 1 ||
            (varying.isNotEmpty && multiAxis == MultiAxisDimension.components)
        ? varying
        : [delta / distance];

    // The dimensions of one call show together, so their labels form one
    // set and share a unit.
    final labels = format.formatLabels([
      for (final direction in directions)
        worldUnits.convertTo(delta.dot(direction), format.unitSystem),
    ], numbers: numbers);

    final builder = _DimensionBuilder(
      camera: camera,
      verticalFovRadians: verticalFovRadians,
      viewportSize: viewportSize,
      convention: convention,
      style: style,
      resolveText: resolveText,
      key: key,
      opacity: opacity,
    );
    final primitives = <Primitive>[];
    for (var i = 0; i < directions.length; i++) {
      final dimension = builder.build(
        from,
        to,
        directions[i],
        offsetDirection,
        labels[i],
      );
      if (dimension == null) return const [];
      primitives.addAll(dimension);
    }
    return primitives;
  }
}

class _DimensionBuilder {
  _DimensionBuilder({
    required this.camera,
    required this.verticalFovRadians,
    required this.viewportSize,
    required this.convention,
    required this.style,
    required this.resolveText,
    required this.key,
    required this.opacity,
  });

  final CameraBasis camera;
  final double verticalFovRadians;
  final vm.Vector2 viewportSize;
  final DraftingConvention convention;
  final DimensionStyle style;
  final TextResolver resolveText;
  final Object? key;
  final double opacity;

  double? _pixel(vm.Vector3 point) => ScreenSpaceUtils.worldUnitsPerPixelAt(
    point,
    camera,
    verticalFovRadians,
    viewportSize.y,
  );

  /// [v] in screen coordinates: its components along screen right and up.
  vm.Vector2 _onScreen(vm.Vector3 v) =>
      vm.Vector2(v.dot(camera.right), v.dot(camera.up));

  LinePrimitive _line(vm.Vector3 start, vm.Vector3 end) => LinePrimitive(
    start: start,
    end: end,
    widthPixels: style.lineWidth,
    key: key,
    opacity: opacity,
  );

  /// A unit vector perpendicular to [direction] that faces the viewer,
  /// turned toward screen up, or toward screen right when it lies
  /// level on screen.
  vm.Vector3 _viewerPerpendicular(vm.Vector3 direction) {
    var perpendicular = direction.cross(camera.toViewer);
    if (perpendicular.length <= _epsilon) {
      // The direction runs along the view axis, so screen up is already
      // perpendicular to it.
      perpendicular = camera.up - direction * camera.up.dot(direction);
    }
    perpendicular.normalize();
    final upward = perpendicular.dot(camera.up);
    final flip = upward.abs() > _epsilon
        ? upward < 0
        : perpendicular.dot(camera.right) < 0;
    return flip ? -perpendicular : perpendicular;
  }

  vm.Vector3 _offsetDirection(vm.Vector3 direction, vm.Vector3? requested) {
    if (requested != null) {
      final perpendicular = requested - direction * requested.dot(direction);
      if (perpendicular.length > _epsilon) return perpendicular.normalized();
    }
    return _viewerPerpendicular(direction);
  }

  List<Primitive>? build(
    vm.Vector3 from,
    vm.Vector3 to,
    vm.Vector3 direction,
    vm.Vector3? requestedOffset,
    String label,
  ) {
    final measured = (to - from).dot(direction);
    final pointsPixel = _pixel((from + to) / 2);
    final fromPixel = _pixel(from);
    final toPixel = _pixel(to);
    if (pointsPixel == null || fromPixel == null || toPixel == null) {
      return null;
    }

    final offset = _offsetDirection(direction, requestedOffset);
    final footFrom = from + offset * (style.offsetPixels * pointsPixel);
    final footTo = footFrom + direction * measured;
    final middle = (footFrom + footTo) / 2;
    final footFromPixel = _pixel(footFrom);
    final footToPixel = _pixel(footTo);
    final middlePixel = _pixel(middle);
    final screenFrom = ScreenSpaceUtils.worldToScreen(
      footFrom,
      camera,
      verticalFovRadians,
      viewportSize,
    );
    final screenTo = ScreenSpaceUtils.worldToScreen(
      footTo,
      camera,
      verticalFovRadians,
      viewportSize,
    );
    if (footFromPixel == null ||
        footToPixel == null ||
        middlePixel == null ||
        screenFrom == null ||
        screenTo == null) {
      return null;
    }

    final gap = style.witnessGapFor(convention.standard);
    LinePrimitive witness(
      vm.Vector3 point,
      vm.Vector3 foot,
      double pointPixel,
      double footPixel,
    ) {
      final span = foot - point;
      final length = span.length;
      final along = length > _epsilon ? span / length : offset;
      return _line(
        point + along * math.min(gap * pointPixel, length),
        foot + along * (style.witnessExtensionPixels * footPixel),
      );
    }

    final content = resolveText(
      TextRequest(text: label, heightPixels: style.textPixelSize),
    );

    // The line's direction on screen, y up, and its length in pixels.
    final screenLength = screenTo.distanceTo(screenFrom);
    final lineOnScreen = _onScreen(direction);
    final screenDirection = lineOnScreen.length > _epsilon
        ? lineOnScreen.normalized()
        : vm.Vector2.zero();
    final textExtent = convention.placement == DimensionTextPlacement.oriented
        ? content.widthPixels
        : content.widthPixels * screenDirection.x.abs() +
              content.heightPixels * screenDirection.y.abs();
    // A line seen end-on has no screen direction to set text along.
    final fits =
        lineOnScreen.length > _epsilon &&
        textExtent + 2 * (style.arrowLengthPixels + style.textGapPixels) <=
            screenLength;
    final placement = fits
        ? convention.placement
        : DimensionTextPlacement.referencing;

    final primitives = <Primitive>[
      witness(from, footFrom, fromPixel, footFromPixel),
      witness(to, footTo, toPixel, footToPixel),
    ];

    if (placement == DimensionTextPlacement.inlined) {
      // Half the break, converted from pixels along the line's screen
      // direction to world units along the line.
      final halfBreak =
          (textExtent / 2 + style.textGapPixels) *
          middlePixel /
          lineOnScreen.length;
      primitives
        ..add(_line(footFrom, middle - direction * halfBreak))
        ..add(_line(middle + direction * halfBreak, footTo));
    } else {
      primitives.add(_line(footFrom, footTo));
    }

    primitives
      ..addAll(_arrowhead(footFrom, direction, footFromPixel))
      ..addAll(_arrowhead(footTo, -direction, footToPixel));

    switch (placement) {
      case DimensionTextPlacement.oriented:
        primitives.add(_orientedText(content, middle, lineOnScreen));
      case DimensionTextPlacement.inlined:
        primitives.add(
          BillboardPrimitive(
            content: content,
            anchor: middle,
            key: key,
            opacity: opacity,
          ),
        );
      case DimensionTextPlacement.referencing:
        final quadrant = _referenceQuadrant(screenDirection, _onScreen(offset));
        final leader = computeCalloutLeaderGeometry(
          anchor: middle,
          cameraRight: camera.right,
          cameraUp: camera.up,
          worldUnitsPerPixel: middlePixel,
          quadrant: quadrant,
          style: style.leader,
        );
        primitives
          ..addAll(
            createCalloutLeaderLines(
              leader: leader,
              key: key,
              opacity: opacity,
            ),
          )
          ..add(
            createCalloutLabel(
              leader: leader,
              quadrant: quadrant,
              content: content,
              key: key,
              opacity: opacity,
            ),
          );
    }
    return primitives;
  }

  /// The two barbs of an open arrowhead whose tip is [tip], its shaft
  /// running along [inward].
  List<LinePrimitive> _arrowhead(
    vm.Vector3 tip,
    vm.Vector3 inward,
    double pixel,
  ) {
    var across = inward.cross(camera.toViewer);
    across = across.length > _epsilon ? across.normalized() : camera.up;
    final base = tip + inward * (style.arrowLengthPixels * pixel);
    final halfWidth = across * (style.arrowWidthPixels / 2 * pixel);
    return [_line(tip, base + halfWidth), _line(tip, base - halfWidth)];
  }

  /// Text parallel to the line on screen, read left to right, or bottom to
  /// top on a vertical line, and lifted off the line by the text gap.
  BillboardPrimitive _orientedText(
    BillboardContent content,
    vm.Vector3 middle,
    vm.Vector2 lineOnScreen,
  ) {
    var along = lineOnScreen.normalized();
    final backward = along.x.abs() > _epsilon ? along.x < 0 : along.y < 0;
    if (backward) along = -along;
    final right = camera.right * along.x + camera.up * along.y;
    // A quarter turn counterclockwise on screen: the text's own up.
    final up = camera.right * -along.y + camera.up * along.x;
    return BillboardPrimitive(
      content: content,
      anchor: middle,
      orientation: CoplanarOrientation(normal: camera.toViewer, right: right),
      alignment: _bottomCenter.clone(),
      offset: ScreenOffset(direction: up, pixels: style.textGapPixels),
      key: key,
      opacity: opacity,
    );
  }

  /// The callout quadrant whose leader leaves the line on its outer side,
  /// [outward], at the widest angle from the line's screen direction
  /// [along]. When no quadrant leaves on the outer side, every quadrant
  /// competes. Ties go to the earlier quadrant.
  CalloutQuadrant _referenceQuadrant(vm.Vector2 along, vm.Vector2 outward) {
    vm.Vector2 leaving(CalloutQuadrant q) =>
        calloutLeaderDirection(q, style: style.leader);
    final outer = [
      for (final q in CalloutQuadrant.values)
        if (leaving(q).dot(outward) > _epsilon) q,
    ];
    final candidates = outer.isEmpty ? CalloutQuadrant.values : outer;
    var best = candidates.first;
    var bestOverlap = leaving(best).dot(along).abs();
    for (final q in candidates.skip(1)) {
      final overlap = leaving(q).dot(along).abs();
      if (overlap < bestOverlap - _epsilon) {
        best = q;
        bestOverlap = overlap;
      }
    }
    return best;
  }
}
