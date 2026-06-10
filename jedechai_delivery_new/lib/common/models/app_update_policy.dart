import 'package:flutter/foundation.dart';

enum AppUpdateMode { optional, force }

enum AppUpdateDecision { none, optional, force }

class AppUpdatePolicy {
  const AppUpdatePolicy({
    required this.enabled,
    required this.mode,
    this.latestVersion,
    this.latestBuild,
    this.minSupportedVersion,
    this.minSupportedBuild,
    this.titleTh,
    this.messageTh,
    this.androidUrl,
    this.iosUrl,
    this.targetRoles = const [],
    this.startsAt,
    this.endsAt,
  });

  factory AppUpdatePolicy.fromJson(Object? raw) {
    if (raw is! Map) return AppUpdatePolicy.disabled;
    final json = Map<String, dynamic>.from(raw);

    return AppUpdatePolicy(
      enabled: json['enabled'] == true,
      mode: _parseMode(json['mode']),
      latestVersion: _stringOrNull(json['latest_version']),
      latestBuild: _intOrNull(json['latest_build']),
      minSupportedVersion: _stringOrNull(json['min_supported_version']),
      minSupportedBuild: _intOrNull(json['min_supported_build']),
      titleTh: _stringOrNull(json['title_th']),
      messageTh: _stringOrNull(json['message_th']),
      androidUrl: _stringOrNull(json['android_url']),
      iosUrl: _stringOrNull(json['ios_url']),
      targetRoles: _stringList(json['target_roles']),
      startsAt: _dateOrNull(json['starts_at']),
      endsAt: _dateOrNull(json['ends_at']),
    );
  }

  static const disabled = AppUpdatePolicy(
    enabled: false,
    mode: AppUpdateMode.optional,
  );

  final bool enabled;
  final AppUpdateMode mode;
  final String? latestVersion;
  final int? latestBuild;
  final String? minSupportedVersion;
  final int? minSupportedBuild;
  final String? titleTh;
  final String? messageTh;
  final String? androidUrl;
  final String? iosUrl;
  final List<String> targetRoles;
  final DateTime? startsAt;
  final DateTime? endsAt;

  AppUpdateDecision evaluate({
    required String currentVersion,
    required int? currentBuild,
    DateTime? now,
    String? role,
    TargetPlatform? platform,
  }) {
    if (!enabled) return AppUpdateDecision.none;

    final effectiveNow = now ?? DateTime.now();
    if (startsAt != null && effectiveNow.isBefore(startsAt!)) {
      return AppUpdateDecision.none;
    }
    if (endsAt != null && effectiveNow.isAfter(endsAt!)) {
      return AppUpdateDecision.none;
    }
    if (targetRoles.isNotEmpty &&
        (role == null || !targetRoles.contains(role))) {
      return AppUpdateDecision.none;
    }

    if (_isCurrentBehind(
      currentVersion: currentVersion,
      currentBuild: currentBuild,
      targetVersion: minSupportedVersion,
      targetBuild: minSupportedBuild,
    )) {
      return _safeDecision(AppUpdateDecision.force, platform);
    }

    final hasAvailableUpdate = _isCurrentBehind(
      currentVersion: currentVersion,
      currentBuild: currentBuild,
      targetVersion: latestVersion,
      targetBuild: latestBuild,
    );
    if (!hasAvailableUpdate) return AppUpdateDecision.none;

    return _safeDecision(
      mode == AppUpdateMode.force
          ? AppUpdateDecision.force
          : AppUpdateDecision.optional,
      platform,
    );
  }

  String? storeUrlForPlatform(TargetPlatform platform) {
    if (platform == TargetPlatform.iOS) return iosUrl ?? androidUrl;
    if (platform == TargetPlatform.android) return androidUrl ?? iosUrl;
    return androidUrl ?? iosUrl;
  }

  bool hasUsableStoreUrlForPlatform(TargetPlatform platform) {
    final url = storeUrlForPlatform(platform);
    final uri = Uri.tryParse(url ?? '');
    return uri != null &&
        (uri.scheme == 'https' || uri.scheme == 'http') &&
        uri.host.isNotEmpty;
  }

  AppUpdateDecision _safeDecision(
    AppUpdateDecision decision,
    TargetPlatform? platform,
  ) {
    if (decision != AppUpdateDecision.force || platform == null) {
      return decision;
    }
    return hasUsableStoreUrlForPlatform(platform)
        ? AppUpdateDecision.force
        : AppUpdateDecision.optional;
  }

  String get displayTitle => titleTh ?? 'มีเวอร์ชันใหม่';

  String get displayMessage =>
      messageTh ?? 'กรุณาอัปเดตแอปเพื่อใช้งานฟีเจอร์ล่าสุด';

  String get targetLabel {
    if (latestVersion != null && latestVersion!.isNotEmpty) {
      return latestVersion!;
    }
    if (latestBuild != null) return 'build $latestBuild';
    return 'เวอร์ชันล่าสุด';
  }

  static AppUpdateMode _parseMode(Object? value) {
    return value?.toString().trim().toLowerCase() == 'force'
        ? AppUpdateMode.force
        : AppUpdateMode.optional;
  }

  static String? _stringOrNull(Object? value) {
    final text = value?.toString().trim();
    return text == null || text.isEmpty ? null : text;
  }

  static int? _intOrNull(Object? value) {
    if (value is int) return value;
    if (value is num) return value.round();
    return int.tryParse(value?.toString().trim() ?? '');
  }

  static DateTime? _dateOrNull(Object? value) {
    final text = _stringOrNull(value);
    return text == null ? null : DateTime.tryParse(text);
  }

  static List<String> _stringList(Object? value) {
    if (value is! Iterable) return const [];
    return value
        .map((item) => item?.toString().trim())
        .whereType<String>()
        .where((item) => item.isNotEmpty)
        .toList(growable: false);
  }

  static bool _isCurrentBehind({
    required String currentVersion,
    required int? currentBuild,
    required String? targetVersion,
    required int? targetBuild,
  }) {
    if (currentBuild != null && targetBuild != null) {
      return currentBuild < targetBuild;
    }
    if (targetVersion == null || targetVersion.isEmpty) return false;
    return _compareVersions(currentVersion, targetVersion) < 0;
  }

  static int _compareVersions(String current, String target) {
    final currentParts = _versionParts(current);
    final targetParts = _versionParts(target);
    final maxLength = currentParts.length > targetParts.length
        ? currentParts.length
        : targetParts.length;

    for (var i = 0; i < maxLength; i++) {
      final left = i < currentParts.length ? currentParts[i] : 0;
      final right = i < targetParts.length ? targetParts[i] : 0;
      if (left != right) return left.compareTo(right);
    }
    return 0;
  }

  static List<int> _versionParts(String version) {
    return version
        .split(RegExp(r'[.+-]'))
        .map((part) => int.tryParse(part) ?? 0)
        .toList(growable: false);
  }
}
