/// Unit system for technical visualization dimensions and measurements.
///
/// Provides conversions between metric (mm) and imperial (in) systems,
/// along with step sequences for interactive controls (move increments,
/// grid subdivisions, scale bar ticks).
enum UnitSystem {
  /// Metric system — base unit is millimeters.
  metric(
    abbreviation: 'mm',
    baseUnit: 'mm',
    label: 'Metric (mm)',
    decimalPlaces: 3,
    toMmFactor: 1.0,
  ),

  /// Imperial system — base unit is inches.
  imperial(
    abbreviation: 'in',
    baseUnit: 'in',
    label: 'Imperial (in)',
    decimalPlaces: 4,
    toMmFactor: 25.4,
  );

  const UnitSystem({
    required this.abbreviation,
    required this.baseUnit,
    required this.label,
    required this.decimalPlaces,
    required double toMmFactor,
  }) : _toMmFactor = toMmFactor;

  /// Short unit abbreviation (e.g. "mm", "in").
  final String abbreviation;

  /// Base unit name (same as [abbreviation] for these systems).
  final String baseUnit;

  /// Human-readable label (e.g. "Metric (mm)").
  final String label;

  /// Recommended decimal places for display formatting.
  final int decimalPlaces;

  /// Conversion factor: 1 base-unit = [_toMmFactor] mm.
  final double _toMmFactor;

  /// Convert [value] from this unit system to [target].
  double convertTo(double value, UnitSystem target) {
    if (this == target) return value;
    // Convert to mm first, then to target.
    final mm = value * _toMmFactor;
    return mm / target._toMmFactor;
  }

  /// Coarse step increments for interactive controls (coarse moves, grid
  /// major lines).
  ///
  /// Sorted ascending. Values are in this system's base unit.
  List<double> get coarseSteps => switch (this) {
    metric => const [1.0, 5.0, 10.0, 50.0, 100.0],
    imperial => const [0.025, 0.05, 0.1, 0.25, 0.5, 1.0],
  };

  /// Fine step increments for precision controls (fine moves, grid minor
  /// lines).
  ///
  /// Sorted ascending. Values are in this system's base unit.
  List<double> get fineSteps => switch (this) {
    metric => const [0.01, 0.05, 0.1, 0.5],
    imperial => const [0.001, 0.005, 0.01, 0.05],
  };
}
