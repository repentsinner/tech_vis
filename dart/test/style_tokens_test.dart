import 'dart:convert';
import 'dart:io';

import 'package:tech_vis/tech_vis.dart';
import 'package:test/test.dart';

/// The source of truth sits outside the package, so it exists in a
/// repository checkout and is absent from the published archive.
final _tokensJson = File('../style/tokens.json');

double _resolve(Map<String, dynamic> entries, String name) {
  final entry = entries[name] as Map<String, dynamic>;
  final alias = entry['alias'] as String?;
  return alias != null
      ? _resolve(entries, alias)
      : (entry['value'] as num).toDouble();
}

void main() {
  final skip = _tokensJson.existsSync()
      ? null
      : 'style/tokens.json is outside the published archive';

  group('StyleTokens', () {
    late Map<String, dynamic> source;

    setUp(() {
      source =
          jsonDecode(_tokensJson.readAsStringSync()) as Map<String, dynamic>;
    });

    test('style version matches the source', () {
      expect(StyleTokens.styleVersion, source['styleVersion']);
    });

    test('every token is generated with its value', () {
      final entries = source['tokens'] as Map<String, dynamic>;
      expect(StyleTokens.all.keys.toSet(), entries.keys.toSet());
      for (final name in entries.keys) {
        expect(StyleTokens.all[name], _resolve(entries, name), reason: name);
      }
    });

    test('layout constants take their values from the tokens', () {
      expect(
        SceneLayoutConstants.calloutGapPixels,
        StyleTokens.all['calloutGapPixels'],
      );
      expect(
        SceneLayoutConstants.calloutBorderThickness,
        SceneLayoutConstants.calloutLeaderLineWidth,
      );
    });
  }, skip: skip);
}
