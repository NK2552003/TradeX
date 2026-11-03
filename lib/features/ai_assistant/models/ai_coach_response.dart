import 'dart:convert';

import 'package:flutter/foundation.dart';

/// The stable response contract rendered by the AI trading coach.
///
/// The parser accepts the human-readable contract as well as the JSON variant
/// so provider formatting can change without changing the presentation layer.
@immutable
class AiCoachResponse {
  const AiCoachResponse({
    required this.label,
    required this.title,
    required this.initialRiskReward,
    required this.extendedRiskReward,
    required this.plan,
    required this.closing,
  });

  final String label;
  final String title;
  final String initialRiskReward;
  final String extendedRiskReward;
  final List<String> plan;
  final String closing;

  static AiCoachResponse? tryParse(String raw) {
    final String text = raw.trim();
    if (text.isEmpty) return null;

    final AiCoachResponse? jsonResponse = _parseJson(text);
    if (jsonResponse != null) return jsonResponse;
    return _parseLabeledText(text);
  }

  static AiCoachResponse? _parseJson(String text) {
    String candidate = text;
    final RegExp fenced = RegExp(
      r'```(?:json)?\s*([\s\S]*?)```',
      caseSensitive: false,
    );
    final RegExpMatch? fenceMatch = fenced.firstMatch(text);
    if (fenceMatch != null) candidate = fenceMatch.group(1)!.trim();

    final int start = candidate.indexOf('{');
    final int end = candidate.lastIndexOf('}');
    if (start < 0 || end <= start) return null;
    try {
      final Object? decoded = jsonDecode(candidate.substring(start, end + 1));
      if (decoded is! Map<String, dynamic>) return null;
      final List<String> plan = (decoded['plan'] as List? ?? const <Object?>[])
          .map((Object? item) => item?.toString().trim() ?? '')
          .where((String item) => item.isNotEmpty)
          .take(5)
          .toList(growable: false);
      return _complete(
        label: decoded['label']?.toString(),
        title: decoded['title']?.toString(),
        initial: decoded['rr_initial']?.toString(),
        extended: decoded['rr_extended']?.toString(),
        plan: plan,
        closing: decoded['closing']?.toString(),
      );
    } on FormatException {
      return null;
    }
  }

  static AiCoachResponse? _parseLabeledText(String text) {
    final List<String> lines = text
        .split(RegExp(r'\r?\n'))
        .map((String line) => line.trim())
        .toList(growable: false);
    String? valueAfter(RegExp pattern) {
      for (final String line in lines) {
        final RegExpMatch? match = pattern.firstMatch(line);
        if (match != null) return match.group(1)?.trim();
      }
      return null;
    }

    final String? label = valueAfter(
      RegExp(r'^Label\s*:\s*(.+)$', caseSensitive: false),
    );
    final String? title = valueAfter(
      RegExp(r'^Title\s*:\s*(.+)$', caseSensitive: false),
    );
    final String? initial = valueAfter(
      RegExp(r'^(?:-\s*)?Initial\s*:\s*(.+)$', caseSensitive: false),
    );
    final String? extended = valueAfter(
      RegExp(r'^(?:-\s*)?Extended\s*:\s*(.+)$', caseSensitive: false),
    );
    final int planHeading = lines.indexWhere(
      (String line) =>
          RegExp(r'^The plan\s*:?$', caseSensitive: false).hasMatch(line),
    );
    final List<String> plan = <String>[];
    if (planHeading >= 0) {
      for (final String line in lines.skip(planHeading + 1)) {
        final RegExpMatch? item = RegExp(
          r'^([1-5])\.\s+(.+)$',
        ).firstMatch(line);
        if (item != null) plan.add(item.group(2)!.trim());
        if (plan.length == 5) break;
      }
    }
    final String? closing = valueAfter(
      RegExp(r'^Closing line\s*:\s*(.+)$', caseSensitive: false),
    );
    return _complete(
      label: label,
      title: title,
      initial: initial,
      extended: extended,
      plan: plan,
      closing: closing,
    );
  }

  static AiCoachResponse? _complete({
    required String? label,
    required String? title,
    required String? initial,
    required String? extended,
    required List<String> plan,
    required String? closing,
  }) {
    if ([
      label,
      title,
      initial,
      extended,
      closing,
    ].any((String? value) => value == null || value.isEmpty)) {
      return null;
    }
    if (plan.length != 5) return null;
    return AiCoachResponse(
      label: label!,
      title: title!,
      initialRiskReward: initial!,
      extendedRiskReward: extended!,
      plan: List<String>.unmodifiable(plan),
      closing: closing!,
    );
  }
}
