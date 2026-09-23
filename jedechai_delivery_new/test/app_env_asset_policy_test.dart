import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// กันไม่ให้ secret หลุดเข้าแอปอีก — ไฟล์ env ที่เป็น Flutter asset ถูกแตกอ่านได้จาก APK/IPA
void main() {
  const clientEnvFile = '.env.client';
  const allowedClientKeys = {
    'SUPABASE_URL',
    'SUPABASE_ANON_KEY',
    'GOOGLE_MAPS_API_KEY',
    'PASSWORD_RESET_REDIRECT_URL',
    'FIREBASE_PROJECT_ID',
  };
  final forbiddenKeyPattern = RegExp(
    r'(SERVICE_KEY|SERVICE_ROLE|SECRET|PRIVATE_KEY|DATABASE_URL|_TOKEN|OPENAI|RESEND|SMSKUB)',
  );

  List<String> declaredAssets() {
    final lines = File('pubspec.yaml').readAsLinesSync();
    final assets = <String>[];
    var inAssets = false;
    for (final line in lines) {
      if (RegExp(r'^\s{2}assets:\s*$').hasMatch(line)) {
        inAssets = true;
        continue;
      }
      if (inAssets) {
        final m = RegExp(r'^\s{4}-\s*(.+?)\s*$').firstMatch(line);
        if (m == null) break;
        assets.add(m.group(1)!);
      }
    }
    return assets;
  }

  test('pubspec bundles only the client env file', () {
    final envAssets =
        declaredAssets().where((a) => a.startsWith('.env')).toList();
    expect(envAssets, [clientEnvFile]);
  });

  test('client env file contains only allow-listed public keys', () {
    final file = File(clientEnvFile);
    if (!file.existsSync()) {
      markTestSkipped('$clientEnvFile not present (CI without secrets)');
      return;
    }
    final keys = file
        .readAsLinesSync()
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty && !l.startsWith('#') && l.contains('='))
        .map((l) => l.substring(0, l.indexOf('=')).trim())
        .toList();
    for (final key in keys) {
      expect(allowedClientKeys, contains(key), reason: 'key not allowed: $key');
      expect(forbiddenKeyPattern.hasMatch(key), isFalse, reason: key);
    }
  });

  test('app code never reads server-side secrets from dotenv', () {
    final offenders = <String>[];
    final dotenvRead = RegExp(r"""dotenv\.(env\[|get\(|maybeGet\()['"]([A-Z_]+)""");
    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      for (final m in dotenvRead.allMatches(entity.readAsStringSync())) {
        final key = m.group(2)!;
        if (!allowedClientKeys.contains(key)) {
          offenders.add('${entity.path}: $key');
        }
      }
    }
    expect(offenders, isEmpty);
  });
}
