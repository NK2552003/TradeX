import 'package:flutter/foundation.dart';

enum AppUpdateUrgency { none, recommended, required }

@immutable
class AppSemanticVersion implements Comparable<AppSemanticVersion> {
  const AppSemanticVersion._({
    required this.major,
    required this.minor,
    required this.patch,
    required this.prerelease,
  });

  factory AppSemanticVersion.parse(String raw) {
    final normalized = raw.trim().replaceFirst(RegExp(r'^[vV]'), '');
    final withoutBuild = normalized.split('+').first;
    final versionParts = withoutBuild.split('-');
    final core = versionParts.first.split('.');
    if (core.length != 3 ||
        core.any(
          (part) =>
              int.tryParse(part) == null ||
              (part.length > 1 && part.startsWith('0')),
        )) {
      throw FormatException('Invalid semantic version', raw);
    }
    final prerelease = versionParts.length <= 1
        ? const <String>[]
        : versionParts.sublist(1).join('-').split('.');
    if (prerelease.any(
      (part) =>
          part.isEmpty ||
          !RegExp(r'^[0-9A-Za-z-]+$').hasMatch(part) ||
          (int.tryParse(part) != null &&
              part.length > 1 &&
              part.startsWith('0')),
    )) {
      throw FormatException('Invalid semantic prerelease', raw);
    }
    return AppSemanticVersion._(
      major: int.parse(core[0]),
      minor: int.parse(core[1]),
      patch: int.parse(core[2]),
      prerelease: List<String>.unmodifiable(prerelease),
    );
  }

  static AppSemanticVersion? tryParse(String raw) {
    try {
      return AppSemanticVersion.parse(raw);
    } on FormatException {
      return null;
    }
  }

  final int major;
  final int minor;
  final int patch;
  final List<String> prerelease;

  @override
  int compareTo(AppSemanticVersion other) {
    for (final comparison in <int>[
      major.compareTo(other.major),
      minor.compareTo(other.minor),
      patch.compareTo(other.patch),
    ]) {
      if (comparison != 0) return comparison;
    }
    if (prerelease.isEmpty && other.prerelease.isEmpty) return 0;
    if (prerelease.isEmpty) return 1;
    if (other.prerelease.isEmpty) return -1;
    final length = prerelease.length > other.prerelease.length
        ? prerelease.length
        : other.prerelease.length;
    for (var index = 0; index < length; index++) {
      if (index >= prerelease.length) return -1;
      if (index >= other.prerelease.length) return 1;
      final left = prerelease[index];
      final right = other.prerelease[index];
      final leftNumber = int.tryParse(left);
      final rightNumber = int.tryParse(right);
      final int comparison;
      if (leftNumber != null && rightNumber != null) {
        comparison = leftNumber.compareTo(rightNumber);
      } else if (leftNumber != null) {
        comparison = -1;
      } else if (rightNumber != null) {
        comparison = 1;
      } else {
        comparison = left.compareTo(right);
      }
      if (comparison != 0) return comparison;
    }
    return 0;
  }

  @override
  String toString() {
    final core = '$major.$minor.$patch';
    return prerelease.isEmpty ? core : '$core-${prerelease.join('.')}';
  }
}

@immutable
class AppBuildIdentity {
  const AppBuildIdentity({
    required this.appName,
    required this.packageName,
    required this.platform,
    required this.version,
    required this.buildNumber,
  });

  final String appName;
  final String packageName;
  final String platform;
  final AppSemanticVersion version;
  final int buildNumber;

  String get displayVersion => '${version.toString()}+$buildNumber';
}

@immutable
class AppPlatformRelease {
  const AppPlatformRelease({
    required this.enabled,
    required this.latestVersion,
    required this.latestBuildNumber,
    required this.minimumVersion,
    required this.minimumBuildNumber,
    required this.updateUri,
    required this.summary,
  });

  factory AppPlatformRelease.fromJson(Map<String, dynamic> json) {
    final latestVersion = AppSemanticVersion.parse(
      json['latest_version'] as String,
    );
    final minimumVersion = AppSemanticVersion.parse(
      json['minimum_supported_version'] as String,
    );
    final latestBuildNumber = _nonNegativeInt(json['latest_build_number']);
    final minimumBuildNumber = _nonNegativeInt(json['minimum_build_number']);
    if (_compareVersionAndBuild(
          minimumVersion,
          minimumBuildNumber,
          latestVersion,
          latestBuildNumber,
        ) >
        0) {
      throw const FormatException(
        'Minimum supported release cannot exceed latest release',
      );
    }
    final updateUri = _secureUri(json['update_url']);
    final summary = (json['summary'] as String? ?? '').trim();
    if (summary.length > 500) {
      throw const FormatException('Update summary is too long');
    }
    return AppPlatformRelease(
      enabled: json['enabled'] != false,
      latestVersion: latestVersion,
      latestBuildNumber: latestBuildNumber,
      minimumVersion: minimumVersion,
      minimumBuildNumber: minimumBuildNumber,
      updateUri: updateUri,
      summary: summary,
    );
  }

  final bool enabled;
  final AppSemanticVersion latestVersion;
  final int latestBuildNumber;
  final AppSemanticVersion minimumVersion;
  final int minimumBuildNumber;
  final Uri? updateUri;
  final String summary;

  String get latestDisplay => '$latestVersion+$latestBuildNumber';

  AppUpdateUrgency urgencyFor(AppBuildIdentity current) {
    if (!enabled) return AppUpdateUrgency.none;
    if (_compareVersionAndBuild(
          current.version,
          current.buildNumber,
          minimumVersion,
          minimumBuildNumber,
        ) <
        0) {
      return AppUpdateUrgency.required;
    }
    if (_compareVersionAndBuild(
          current.version,
          current.buildNumber,
          latestVersion,
          latestBuildNumber,
        ) <
        0) {
      return AppUpdateUrgency.recommended;
    }
    return AppUpdateUrgency.none;
  }
}

@immutable
class AppUpdateManifest {
  const AppUpdateManifest({
    required this.generatedAt,
    required this.releaseNotesUri,
    required this.platforms,
  });

  factory AppUpdateManifest.fromJson(Map<String, dynamic> json) {
    if (json['schema_version'] != 1) {
      throw const FormatException('Unsupported update manifest schema');
    }
    final platformJson = json['platforms'];
    if (platformJson is! Map) {
      throw const FormatException('Update manifest is missing platforms');
    }
    final releases = <String, AppPlatformRelease>{};
    for (final entry in platformJson.entries) {
      if (entry.key is! String || entry.value is! Map) continue;
      releases[entry.key as String] = AppPlatformRelease.fromJson(
        Map<String, dynamic>.from(entry.value as Map),
      );
    }
    final generatedAtRaw = json['generated_at'] as String?;
    return AppUpdateManifest(
      generatedAt: generatedAtRaw == null
          ? null
          : DateTime.tryParse(generatedAtRaw)?.toUtc(),
      releaseNotesUri: _secureUri(json['release_notes_url']),
      platforms: Map<String, AppPlatformRelease>.unmodifiable(releases),
    );
  }

  final DateTime? generatedAt;
  final Uri? releaseNotesUri;
  final Map<String, AppPlatformRelease> platforms;
}

@immutable
class AppUpdateStatus {
  const AppUpdateStatus({
    required this.current,
    required this.release,
    required this.releaseNotesUri,
    required this.urgency,
    required this.checkedSuccessfully,
    required this.checkedAt,
  });

  final AppBuildIdentity current;
  final AppPlatformRelease? release;
  final Uri? releaseNotesUri;
  final AppUpdateUrgency urgency;
  final bool checkedSuccessfully;
  final DateTime checkedAt;

  bool get hasUpdate => urgency != AppUpdateUrgency.none && release != null;
  bool get isRequired => urgency == AppUpdateUrgency.required;
}

int _compareVersionAndBuild(
  AppSemanticVersion leftVersion,
  int leftBuild,
  AppSemanticVersion rightVersion,
  int rightBuild,
) {
  final versionComparison = leftVersion.compareTo(rightVersion);
  return versionComparison != 0
      ? versionComparison
      : leftBuild.compareTo(rightBuild);
}

int _nonNegativeInt(Object? value) {
  final parsed = switch (value) {
    final int number => number,
    final String text => int.tryParse(text),
    _ => null,
  };
  if (parsed == null || parsed < 0) {
    throw const FormatException('Build number must be non-negative');
  }
  return parsed;
}

Uri? _secureUri(Object? value) {
  if (value is! String || value.trim().isEmpty) return null;
  final uri = Uri.tryParse(value.trim());
  if (uri == null ||
      uri.scheme != 'https' ||
      uri.host.isEmpty ||
      uri.userInfo.isNotEmpty) {
    return null;
  }
  return uri;
}
