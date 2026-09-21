import 'dart:io';

import 'package:test/test.dart';

/// Vocabulary from the domain of the application this package was extracted
/// from. A generic toolkit names nothing from a consumer's domain.
///
/// Terms match as substrings so that camelCase and snake_case identifiers
/// are caught. "state machine" is generic and stays legal.
final _consumerVocabulary = RegExp(
  r'cnc|g-?code|toolpath|spindle|feed[ _-]?rate|workpiece|jog'
  r'|(?<!state[ -])machine|route[ _-]?segment',
  caseSensitive: false,
);

void main() {
  group('consumer vocabulary pattern', () {
    for (final banned in const [
      'CncSceneObject',
      'cnc_scene_description',
      'G-code',
      'gcode',
      'toolpathLine',
      'spindleMode',
      'feedRate',
      'feed rate',
      'workpieceAxisThicknessScale',
      'fine jog',
      'machinePosition',
      'route segment',
    ]) {
      test('matches "$banned"', () {
        expect(_consumerVocabulary.hasMatch(banned), isTrue);
      });
    }

    for (final generic in const [
      'state machine',
      'router',
      'feed',
      'rate',
      'line segment',
    ]) {
      test('allows "$generic"', () {
        expect(_consumerVocabulary.hasMatch(generic), isFalse);
      });
    }
  });

  test('lib/ names nothing from a consumer domain', () {
    final violations = <String>[];
    final sources = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => file.path.endsWith('.dart'));

    for (final source in sources) {
      final lines = source.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        final match = _consumerVocabulary.firstMatch(lines[i]);
        if (match != null) {
          violations.add('${source.path}:${i + 1}: "${match[0]}"');
        }
      }
    }

    expect(violations, isEmpty, reason: violations.join('\n'));
  });
}
