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

/// [v] scaled to unit length, or zero when it has no length.
vm.Vector2 _unit(vm.Vector2 v) =>
    v.length > _epsilon ? v.normalized() : vm.Vector2.zero();

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

/// What a radial dimension measures.
enum RadialMeasure {
  /// The radius, from the center to the rim, written after `R`.
  radius,

  /// The diameter, from rim to rim through the center, written after `⌀`.
  diameter,
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
    this.arcRadiusPixels = StyleTokens.dimensionArcRadiusPixels,
    this.arcSegmentPixels = StyleTokens.dimensionArcSegmentPixels,
    this.angleResolutionDegrees = StyleTokens.dimensionAngleResolutionDegrees,
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

  /// Radius of an angular dimension's arc, from its vertex.
  final double arcRadiusPixels;

  /// Longest segment of an angular dimension's arc, along the arc at the
  /// vertex's depth.
  final double arcSegmentPixels;

  /// Step an angular dimension's value rounds to, in degrees.
  final double angleResolutionDegrees;

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
  /// request. [drafting] places it. An oriented or inlined dimension
  /// whose text and arrowheads do not fit between its witness lines on
  /// screen falls back to its standard's referencing style.
  ///
  /// Returns an empty list for coincident points, or when a point the
  /// dimension needs lies on or behind the camera plane.
  static List<Primitive> create({
    required vm.Vector3 from,
    required vm.Vector3 to,
    required DraftingConvention drafting,
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
      drafting: drafting,
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

  /// Returns the primitives of an angular dimension: the angle at [vertex]
  /// between the legs [first] and [second], vectors from [vertex] to the
  /// far end of each, seen by [camera] with vertical field of view
  /// [verticalFovRadians] in a [viewportSize] viewport.
  ///
  /// The dimension line is an arc in the legs' plane, centered on
  /// [vertex], [DimensionStyle.arcRadiusPixels] from it, from [first] to
  /// [second] the short way round. It draws as straight lines no longer
  /// than [DimensionStyle.arcSegmentPixels] along the arc.
  ///
  /// The dimension emits, in order: a witness line along each leg that
  /// ends short of the arc, extending it past the arc; the arc's lines,
  /// in two runs when inlined text breaks it; two lines per arrowhead, at
  /// the [first] end and then the [second] end; the two leader lines of
  /// a referencing dimension; and the text billboard.
  ///
  /// The text is the angle in decimal degrees, rounded to
  /// [DimensionStyle.angleResolutionDegrees] and written with [numbers],
  /// and [resolveText] answers its request. [drafting] places it at the
  /// arc's midpoint, along the arc's tangent there, and falls back to
  /// referencing when it does not fit along the arc on screen.
  ///
  /// Returns an empty list when a leg is zero, when the legs are parallel
  /// or opposed, or when a point the dimension needs lies on or behind
  /// the camera plane.
  static List<Primitive> createAngular({
    required vm.Vector3 vertex,
    required vm.Vector3 first,
    required vm.Vector3 second,
    required DraftingConvention drafting,
    required CameraBasis camera,
    required double verticalFovRadians,
    required vm.Vector2 viewportSize,
    required TextResolver resolveText,
    required Object? key,
    NumberFormatting numbers = const NumberFormatting(),
    DimensionStyle style = const DimensionStyle(),
    double opacity = 1.0,
  }) {
    final firstLength = first.length;
    final secondLength = second.length;
    if (firstLength <= _epsilon || secondLength <= _epsilon) return const [];
    final along = first / firstLength;
    final toward = second / secondLength;
    final sine = along.cross(toward).length;
    // Parallel legs span no angle, and opposed legs span no plane.
    if (sine <= _epsilon) return const [];
    final angle = math.atan2(sine, along.dot(toward));

    final builder = _DimensionBuilder(
      camera: camera,
      verticalFovRadians: verticalFovRadians,
      viewportSize: viewportSize,
      drafting: drafting,
      style: style,
      resolveText: resolveText,
      key: key,
      opacity: opacity,
    );
    return builder.angular(
          vertex,
          along,
          (toward - along * along.dot(toward)).normalized(),
          angle,
          firstLength,
          secondLength,
          formatDegreesLabel(
            angle * 180 / math.pi,
            step: style.angleResolutionDegrees,
            numbers: numbers,
          ),
        ) ??
        const [];
  }

  /// Returns the primitives of a radial dimension of the circle or arc
  /// centered on [center] with [radius], in the plane through [center]
  /// perpendicular to [normal], seen by [camera] with vertical field of
  /// view [verticalFovRadians] in a [viewportSize] viewport.
  ///
  /// The dimension line lies in the plane along [direction], less its
  /// component along [normal]. Without one, it runs toward the screen's
  /// top-right corner, or toward screen right when that corner lies along
  /// [normal]. For an arc, give a [direction] that points into the arc.
  /// [measure] decides whether the line runs from [center] to the rim, or
  /// across the circle through [center] from rim to rim.
  ///
  /// The dimension emits, in order: the dimension line, as two segments
  /// when inlined text breaks it; two lines per arrowhead, at the rim
  /// along [direction] and then, for a diameter, at the opposite rim; the
  /// two leader lines of a referencing dimension; and the text billboard.
  ///
  /// The text is `R` before a radius and `⌀` before a diameter, then the
  /// length converted from [worldUnits] and written by [format] with
  /// [numbers]. [resolveText] answers its request, and [drafting]
  /// places it at the dimension line's midpoint, falling back to
  /// referencing as a linear dimension does.
  ///
  /// Returns an empty list for a radius that is not positive, a zero
  /// [normal], or when a point the dimension needs lies on or behind the
  /// camera plane.
  static List<Primitive> createRadial({
    required vm.Vector3 center,
    required double radius,
    required vm.Vector3 normal,
    required RadialMeasure measure,
    required DraftingConvention drafting,
    required DisplayFormat format,
    required UnitSystem worldUnits,
    required CameraBasis camera,
    required double verticalFovRadians,
    required vm.Vector2 viewportSize,
    required TextResolver resolveText,
    required Object? key,
    vm.Vector3? direction,
    NumberFormatting numbers = const NumberFormatting(),
    DimensionStyle style = const DimensionStyle(),
    double opacity = 1.0,
  }) {
    if (!(radius > _epsilon) || normal.length <= _epsilon) return const [];
    final axis = normal.normalized();
    vm.Vector3? inPlane(vm.Vector3? v) {
      if (v == null) return null;
      final projected = v - axis * v.dot(axis);
      return projected.length > _epsilon ? projected.normalized() : null;
    }

    // Screen right projects to zero only along the normal, and then the
    // top-right corner does not.
    final along =
        inPlane(direction) ??
        inPlane(camera.right + camera.up) ??
        inPlane(camera.right)!;
    final diameter = measure == RadialMeasure.diameter;
    final length = diameter ? 2 * radius : radius;
    final value = format.formatLabels([
      worldUnits.convertTo(length, format.unitSystem),
    ], numbers: numbers).single;

    final builder = _DimensionBuilder(
      camera: camera,
      verticalFovRadians: verticalFovRadians,
      viewportSize: viewportSize,
      drafting: drafting,
      style: style,
      resolveText: resolveText,
      key: key,
      opacity: opacity,
    );
    return builder.radial(
          diameter ? center - along * radius : center,
          center + along * radius,
          along,
          diameter: diameter,
          label: '${diameter ? '⌀' : 'R'}$value',
        ) ??
        const [];
  }
}

class _DimensionBuilder {
  _DimensionBuilder({
    required this.camera,
    required this.verticalFovRadians,
    required this.viewportSize,
    required this.drafting,
    required this.style,
    required this.resolveText,
    required this.key,
    required this.opacity,
  });

  final CameraBasis camera;
  final double verticalFovRadians;
  final vm.Vector2 viewportSize;
  final DraftingConvention drafting;
  final DimensionStyle style;
  final TextResolver resolveText;
  final Object? key;
  final double opacity;

  vm.Vector2? _screen(vm.Vector3 point) => ScreenSpaceUtils.worldToScreen(
    point,
    camera,
    verticalFovRadians,
    viewportSize,
  );

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
    final screenFrom = _screen(footFrom);
    final screenTo = _screen(footTo);
    if (footFromPixel == null ||
        footToPixel == null ||
        middlePixel == null ||
        screenFrom == null ||
        screenTo == null) {
      return null;
    }

    final gap = style.witnessGapFor(drafting.standard);
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
    final lineOnScreen = _onScreen(direction);
    final (placement, extent) = _fit(
      content,
      lineOnScreen,
      screenTo.distanceTo(screenFrom),
    );

    final primitives = <Primitive>[
      witness(from, footFrom, fromPixel, footFromPixel),
      witness(to, footTo, toPixel, footToPixel),
    ];

    return primitives
      ..addAll(
        _straightLine(
          footFrom,
          footTo,
          direction,
          placement,
          extent,
          middlePixel,
          lineOnScreen,
        ),
      )
      ..addAll(_arrowhead(footFrom, direction, footFromPixel))
      ..addAll(_arrowhead(footTo, -direction, footToPixel))
      ..addAll(
        _text(placement, content, middle, lineOnScreen, offset, middlePixel),
      );
  }

  /// An arc of [angle] radians from the leg [along] toward [across], the
  /// unit perpendicular to it in the legs' plane, centered on [vertex].
  /// The legs end [firstLength] and [secondLength] from [vertex].
  List<Primitive>? angular(
    vm.Vector3 vertex,
    vm.Vector3 along,
    vm.Vector3 across,
    double angle,
    double firstLength,
    double secondLength,
    String label,
  ) {
    final vertexPixel = _pixel(vertex);
    if (vertexPixel == null) return null;
    final radius = style.arcRadiusPixels * vertexPixel;
    vm.Vector3 radial(double t) => along * math.cos(t) + across * math.sin(t);
    vm.Vector3 point(double t) => vertex + radial(t) * radius;
    vm.Vector3 tangent(double t) => along * -math.sin(t) + across * math.cos(t);
    // Segments are counted from the arc's length at the vertex's depth,
    // which no view foreshortens, so the count depends on the style and
    // the angle alone.
    int segments(double span) => math.max(
      1,
      (style.arcRadiusPixels * span / style.arcSegmentPixels).ceil(),
    );

    final count = segments(angle);
    // Each point of the whole arc once: projected for the fit test, and
    // joined directly when no inlined break splits the arc.
    final points = [for (var i = 0; i <= count; i++) point(angle * i / count)];
    final screen = [for (final p in points) _screen(p)];
    final half = angle / 2;
    final middle = point(half);
    final firstEnd = points.first;
    final secondEnd = points.last;
    final middlePixel = _pixel(middle);
    final firstEndPixel = _pixel(firstEnd);
    final secondEndPixel = _pixel(secondEnd);
    final firstTipPixel = _pixel(vertex + along * firstLength);
    final secondTipPixel = _pixel(vertex + radial(angle) * secondLength);
    if (screen.contains(null) ||
        middlePixel == null ||
        firstEndPixel == null ||
        secondEndPixel == null ||
        firstTipPixel == null ||
        secondTipPixel == null) {
      return null;
    }
    var screenLength = 0.0;
    for (var i = 1; i <= count; i++) {
      screenLength += screen[i]!.distanceTo(screen[i - 1]!);
    }

    final gap = style.witnessGapFor(drafting.standard);
    final primitives = <Primitive>[];
    void witness(
      vm.Vector3 leg,
      double length,
      double tipPixel,
      double endPixel,
    ) {
      final start = length + gap * tipPixel;
      if (start >= radius) return;
      primitives.add(
        _line(
          vertex + leg * start,
          vertex + leg * (radius + style.witnessExtensionPixels * endPixel),
        ),
      );
    }

    witness(along, firstLength, firstTipPixel, firstEndPixel);
    witness(radial(angle), secondLength, secondTipPixel, secondEndPixel);

    final content = resolveText(
      TextRequest(text: label, heightPixels: style.textPixelSize),
    );
    final lineOnScreen = _onScreen(tangent(half));
    final (placement, extent) = _fit(content, lineOnScreen, screenLength);

    void run(double from, double to) {
      final n = segments(to - from);
      for (var i = 0; i < n; i++) {
        primitives.add(
          _line(
            point(from + (to - from) * i / n),
            point(from + (to - from) * (i + 1) / n),
          ),
        );
      }
    }

    if (placement == DimensionTextPlacement.inlined) {
      final halfBreak = math.min(
        _halfBreak(extent, middlePixel, lineOnScreen) / radius,
        half,
      );
      run(0, half - halfBreak);
      run(half + halfBreak, angle);
    } else {
      for (var i = 0; i < count; i++) {
        primitives.add(_line(points[i], points[i + 1]));
      }
    }

    return primitives
      ..addAll(_arrowhead(firstEnd, tangent(0), firstEndPixel))
      ..addAll(_arrowhead(secondEnd, -tangent(angle), secondEndPixel))
      ..addAll(
        _text(
          placement,
          content,
          middle,
          lineOnScreen,
          radial(half),
          middlePixel,
        ),
      );
  }

  /// A radial dimension line from [start] to [rim] along the unit
  /// [direction], with an arrowhead on [rim], and on [start] too for a
  /// [diameter].
  List<Primitive>? radial(
    vm.Vector3 start,
    vm.Vector3 rim,
    vm.Vector3 direction, {
    required bool diameter,
    required String label,
  }) {
    final middle = (start + rim) / 2;
    final startPixel = _pixel(start);
    final rimPixel = _pixel(rim);
    final middlePixel = _pixel(middle);
    final screenStart = _screen(start);
    final screenRim = _screen(rim);
    if (startPixel == null ||
        rimPixel == null ||
        middlePixel == null ||
        screenStart == null ||
        screenRim == null) {
      return null;
    }

    final content = resolveText(
      TextRequest(text: label, heightPixels: style.textPixelSize),
    );
    final lineOnScreen = _onScreen(direction);
    final (placement, extent) = _fit(
      content,
      lineOnScreen,
      screenRim.distanceTo(screenStart),
    );
    return [
      ..._straightLine(
        start,
        rim,
        direction,
        placement,
        extent,
        middlePixel,
        lineOnScreen,
      ),
      ..._arrowhead(rim, -direction, rimPixel),
      if (diameter) ..._arrowhead(start, direction, startPixel),
      ..._text(
        placement,
        content,
        middle,
        lineOnScreen,
        _viewerPerpendicular(direction),
        middlePixel,
      ),
    ];
  }

  /// A straight dimension line from [start] to [end] along the unit
  /// [direction]: one line, or two either side of the break that inlined
  /// text of [extent] pixels makes at its midpoint.
  List<LinePrimitive> _straightLine(
    vm.Vector3 start,
    vm.Vector3 end,
    vm.Vector3 direction,
    DimensionTextPlacement placement,
    double extent,
    double middlePixel,
    vm.Vector2 lineOnScreen,
  ) {
    if (placement != DimensionTextPlacement.inlined) return [_line(start, end)];
    final middle = (start + end) / 2;
    final halfBreak = _halfBreak(extent, middlePixel, lineOnScreen);
    return [
      _line(start, middle - direction * halfBreak),
      _line(middle + direction * halfBreak, end),
    ];
  }

  /// The placement of [content] on a dimension line whose unit direction
  /// shows on screen as [lineOnScreen], with [screenLength] pixels between
  /// its ends, and the text's extent along it in pixels.
  ///
  /// Oriented and inlined text that does not fit, with an arrowhead and a
  /// text gap at each end, falls back to referencing.
  (DimensionTextPlacement, double) _fit(
    BillboardContent content,
    vm.Vector2 lineOnScreen,
    double screenLength,
  ) {
    final screenDirection = _unit(lineOnScreen);
    final extent = drafting.placement == DimensionTextPlacement.oriented
        ? content.widthPixels
        : content.widthPixels * screenDirection.x.abs() +
              content.heightPixels * screenDirection.y.abs();
    // A line seen end-on has no screen direction to set text along.
    final fits =
        lineOnScreen.length > _epsilon &&
        extent + 2 * (style.arrowLengthPixels + style.textGapPixels) <=
            screenLength;
    return (
      fits ? drafting.placement : DimensionTextPlacement.referencing,
      extent,
    );
  }

  /// Half the break inlined text of [extent] pixels makes, in world units
  /// along a dimension line whose unit direction shows on screen as
  /// [lineOnScreen], at [middlePixel] world units per pixel.
  double _halfBreak(
    double extent,
    double middlePixel,
    vm.Vector2 lineOnScreen,
  ) => (extent / 2 + style.textGapPixels) * middlePixel / lineOnScreen.length;

  /// The text of a dimension at [middle] of its dimension line, under
  /// [placement]: a billboard, led off the line by a callout leader toward
  /// [outward] when referencing.
  List<Primitive> _text(
    DimensionTextPlacement placement,
    BillboardContent content,
    vm.Vector3 middle,
    vm.Vector2 lineOnScreen,
    vm.Vector3 outward,
    double middlePixel,
  ) {
    switch (placement) {
      case DimensionTextPlacement.oriented:
        return [_orientedText(content, middle, lineOnScreen)];
      case DimensionTextPlacement.inlined:
        return [
          BillboardPrimitive(
            content: content,
            anchor: middle,
            key: key,
            opacity: opacity,
          ),
        ];
      case DimensionTextPlacement.referencing:
        final along = _unit(lineOnScreen);
        final quadrant = _referenceQuadrant(along, _onScreen(outward));
        final leader = computeCalloutLeaderGeometry(
          anchor: middle,
          cameraRight: camera.right,
          cameraUp: camera.up,
          worldUnitsPerPixel: middlePixel,
          quadrant: quadrant,
          style: style.leader,
        );
        return [
          ...createCalloutLeaderLines(
            leader: leader,
            key: key,
            opacity: opacity,
          ),
          createCalloutLabel(
            leader: leader,
            quadrant: quadrant,
            content: content,
            key: key,
            opacity: opacity,
          ),
        ];
    }
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
