import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';

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

  static Future<String> _url(String ref) =>
      StrategiesRepositoryScope.repository.resolveAttachmentUrl(ref);

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

  /// Wire into `RichMarkdownPreview.imageResolver`.
  static Widget resolve(BuildContext context, Uri uri) =>
      NoteAttachments.resolve(context, uri, using: _url);

  /// Wire into `MarkdownPdfExporter.exportAndShare`'s `imageResolver`.
  static Future<Uint8List?> bytesFor(Uri uri) =>
      NoteAttachments.bytesFor(uri, using: _url);
}
