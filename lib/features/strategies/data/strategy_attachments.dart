import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:tradex/core/config/supabase_config.dart';

import '../../notes/data/note_attachments.dart';
import 'strategies_repository.dart';

/// Attachment plumbing for strategy playbooks.
///
/// A playbook's images are usually the annotated example: *this* is what the
/// setup looks like when it is valid, and this is what it looks like when it is
/// not. They belong to the playbook rather than to a note about it, because a
/// playbook that gets shared to the community feed has to take its examples with
/// it, and a private research note must not be dragged along.
///
/// Staging, the markdown form and the rendering are shared with
/// [NoteAttachments] so a body written in any of the three editors renders
/// identically. Only the store differs, which is the one thing that has to: the
/// backend gives playbook files their own bucket and their own row-level policy
/// keyed on the playbook's visibility.
class StrategyAttachments {
  const StrategyAttachments._();

  static final Map<String, ({String url, DateTime expires})> _resolved = {};

  static String _cacheKey(String ref) =>
      '${SupabaseConfig.client?.auth.currentUser?.id ?? 'signedout'}:$ref';

  static String? _cached(String key) {
    final entry = _resolved[key];
    if (entry == null || !entry.expires.isAfter(DateTime.now())) {
      _resolved.remove(key);
      return null;
    }
    return entry.url;
  }

  static void _remember(String key, String url) {
    if (_resolved.length >= 512) _resolved.clear();
    _resolved[key] = (
      url: url,
      expires: DateTime.now().add(const Duration(minutes: 5)),
    );
  }

  static Future<String> _url(String ref) async {
    final key = _cacheKey(ref);
    final cached = _cached(key);
    if (cached != null) return cached;
    final url = await StrategiesRepositoryScope.repository.resolveAttachmentUrl(ref);
    if (url.isNotEmpty) _remember(key, url);
    return url;
  }

  /// Copies [source] out of the OS cache, stores it against [strategyId] and
  /// returns the markdown to drop at the cursor.
  ///
  /// [strategyId] must already exist — an attachment uploaded against an unsaved
  /// draft would have no owner, so callers save first.
  static Future<String> attach({
    required String strategyId,
    required File source,
    required String filename,
  }) async {
    final File staged = await NoteAttachments.stage(source);
    final String ref = await StrategiesRepositoryScope.repository
        .uploadAttachment(strategyId, staged);
    return NoteAttachments.markdownFor(
      ref: ref,
      filename: filename,
      isImage: NoteAttachments.isImageFile(staged.path),
    );
  }

  /// Uploads [bytes] directly and returns the markdown to drop at the cursor.
  /// Works across all platforms including Web without staging to disk.
  static Future<String> attachBytes({
    required String strategyId,
    required Uint8List bytes,
    required String filename,
  }) async {
    final String ref = await StrategiesRepositoryScope.repository.uploadAttachment(
      strategyId,
      null,
      bytes: bytes,
      filename: filename,
    );
    return NoteAttachments.markdownFor(
      ref: ref,
      filename: filename,
      isImage: NoteAttachments.isImageFile(filename),
    );
  }

  /// Wire into `RichMarkdownPreview.imageResolver`.
  static Widget resolve(BuildContext context, Uri uri) =>
      NoteAttachments.resolve(context, uri, using: _url);

  /// Wire into `MarkdownPdfExporter.exportAndShare`'s `imageResolver`.
  static Future<Uint8List?> bytesFor(Uri uri) async {
    try {
      return await NoteAttachments.bytesFor(uri, using: _url);
    } catch (_) {
      return null;
    }
  }

  /// Invalidates cached URLs across all strategy attachments.
  static void clearCache() => _resolved.clear();

  /// Invalidates cached URL for a specific attachment [ref].
  static void invalidate(String ref) {
    _resolved.removeWhere((key, _) => key.endsWith(':$ref') || key.contains(ref));
  }

  /// Invalidates all cached attachments for a specific strategy [strategyId].
  static void invalidateForStrategy(String strategyId) {
    _resolved.removeWhere((key, _) => key.contains('/$strategyId/'));
  }
}
