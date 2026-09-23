import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

// AppBarTheme กำหนด titleTextStyle และ iconTheme เป็นสี onPanel (ขาว)
// ซึ่งชนะ foregroundColor ของ AppBar → AppBar ที่เปลี่ยนพื้นเป็นสีสว่าง
// ต้องกำหนดสองค่านี้เอง ไม่งั้นชื่อหน้า/ปุ่มย้อนกลับเป็นขาวบนขาว
void main() {
  test('AppBar พื้นสว่างกำหนด titleTextStyle และ iconTheme เองทุกจุด', () {
    final lightBg = RegExp(r'backgroundColor:\s*[^,\n]*(surface|paper|sunken|Colors\.white)');
    final offenders = <String>[];
    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final src = entity.readAsStringSync();
      for (final m in RegExp(r'\bAppBar\(').allMatches(src)) {
        var i = m.end, depth = 1;
        while (depth > 0 && i < src.length) {
          final c = src[i];
          if (c == '(') depth++;
          if (c == ')') depth--;
          i++;
        }
        final block = src.substring(m.start, i);
        if (!lightBg.hasMatch(block)) continue;
        final missing = [
          if (!block.contains('titleTextStyle')) 'titleTextStyle',
          if (!block.contains('iconTheme')) 'iconTheme',
        ];
        if (missing.isNotEmpty) {
          final line = '\n'.allMatches(src.substring(0, m.start)).length + 1;
          offenders.add('${entity.path}:$line ขาด ${missing.join(', ')}');
        }
      }
    }
    expect(offenders, isEmpty, reason: offenders.join('\n'));
  });
}
