import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexus/app/theme.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('日本語テーマのフォントをネットワークなしでアプリ資産から読める', () async {
    final theme = NexusTheme.of(NexusPalette.whiteMidnight);
    final family = theme.textTheme.bodyMedium!.fontFamily;
    final manifest =
        jsonDecode(await rootBundle.loadString('FontManifest.json')) as List;
    final entries = manifest
        .where((entry) => entry['family'] == family)
        .toList();
    expect(
      entries,
      isNotEmpty,
      reason:
          'The active Japanese font must be bundled, not fetched at runtime.',
    );
    for (final font in entries.single['fonts'] as List) {
      final bytes = await rootBundle.load(font['asset'] as String);
      expect(bytes.lengthInBytes, greaterThan(0));
    }
  });
}
