import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jedechai_delivery_new/common/models/app_update_policy.dart';

void main() {
  group('AppUpdatePolicy', () {
    test('defaults to disabled when config is missing', () {
      final policy = AppUpdatePolicy.fromJson(null);

      expect(policy.enabled, isFalse);
      expect(
        policy.evaluate(currentVersion: '1.5.1', currentBuild: 91),
        AppUpdateDecision.none,
      );
    });

    test('returns optional update when current build is behind latest build',
        () {
      final policy = AppUpdatePolicy.fromJson({
        'enabled': true,
        'mode': 'optional',
        'latest_version': '1.5.2',
        'latest_build': 92,
        'min_supported_version': '1.5.0',
        'min_supported_build': 90,
      });

      expect(policy.enabled, isTrue);
      expect(policy.mode, AppUpdateMode.optional);
      expect(
        policy.evaluate(currentVersion: '1.5.1', currentBuild: 91),
        AppUpdateDecision.optional,
      );
      expect(
        policy.evaluate(currentVersion: '1.5.2', currentBuild: 92),
        AppUpdateDecision.none,
      );
    });

    test('returns force update when current build is below minimum build', () {
      final policy = AppUpdatePolicy.fromJson({
        'enabled': true,
        'mode': 'optional',
        'latest_version': '1.5.2',
        'latest_build': 92,
        'min_supported_version': '1.5.2',
        'min_supported_build': 92,
      });

      expect(
        policy.evaluate(currentVersion: '1.5.1', currentBuild: 91),
        AppUpdateDecision.force,
      );
    });

    test('force mode turns an available update into a blocking update', () {
      final policy = AppUpdatePolicy.fromJson({
        'enabled': true,
        'mode': 'force',
        'latest_version': '1.5.2',
        'latest_build': 92,
      });

      expect(
        policy.evaluate(currentVersion: '1.5.1', currentBuild: 91),
        AppUpdateDecision.force,
      );
      expect(
        policy.evaluate(currentVersion: '1.5.2', currentBuild: 92),
        AppUpdateDecision.none,
      );
    });

    test('falls back to semantic version comparison when builds are absent',
        () {
      final policy = AppUpdatePolicy.fromJson({
        'enabled': true,
        'mode': 'optional',
        'latest_version': '1.10.0',
        'min_supported_version': '1.8.0',
      });

      expect(
        policy.evaluate(currentVersion: '1.9.9', currentBuild: null),
        AppUpdateDecision.optional,
      );
      expect(
        policy.evaluate(currentVersion: '1.7.9', currentBuild: null),
        AppUpdateDecision.force,
      );
    });

    test('target roles restrict update decisions and unknown role is fail-open',
        () {
      final policy = AppUpdatePolicy.fromJson({
        'enabled': true,
        'mode': 'force',
        'latest_build': 92,
        'target_roles': ['driver'],
      });

      expect(
        policy.evaluate(
          currentVersion: '1.5.1',
          currentBuild: 91,
          role: 'customer',
        ),
        AppUpdateDecision.none,
      );
      expect(
        policy.evaluate(
          currentVersion: '1.5.1',
          currentBuild: 91,
          role: null,
        ),
        AppUpdateDecision.none,
      );
      expect(
        policy.evaluate(
          currentVersion: '1.5.1',
          currentBuild: 91,
          role: 'driver',
        ),
        AppUpdateDecision.force,
      );
    });

    test('force decision downgrades to optional without a usable store URL',
        () {
      final policy = AppUpdatePolicy.fromJson({
        'enabled': true,
        'mode': 'force',
        'latest_build': 92,
        'android_url': '',
        'ios_url': 'not-a-url',
      });

      expect(
        policy.evaluate(
          currentVersion: '1.5.1',
          currentBuild: 91,
          platform: TargetPlatform.android,
        ),
        AppUpdateDecision.optional,
      );
    });
  });
}
