import 'package:tech_vis/tech_vis.dart';
import 'package:vector_math/vector_math_64.dart' as vm;

import 'vectors.dart';

/// The billboards among [primitives], in order.
List<BillboardPrimitive> billboardsOf(List<Primitive> primitives) =>
    primitives.whereType<BillboardPrimitive>().toList();

/// The text of each text-request billboard among [primitives], in order.
List<String> textsOf(List<Primitive> primitives) => [
  for (final b in billboardsOf(primitives))
    (b.content.value! as TextRequest).text,
];

/// The lines among [primitives], in order.
List<LinePrimitive> linesOf(List<Primitive> primitives) =>
    primitives.whereType<LinePrimitive>().toList();

/// Expects [actual] within the vector tolerance of [expected].
void expectVector3(vm.Vector3 actual, vm.Vector3 expected, String reason) =>
    expectNumbers(actual.storage, expected.storage, reason);
