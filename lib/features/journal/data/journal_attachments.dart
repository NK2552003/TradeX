import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../notes/data/note_attachments.dart';
import 'journal_repository.dart';

/// Attachment plumbing for journal entries.
///
/// A marked-up chart is half of what a trade review is worth, so screenshots are
/// the journal's most-used attachment — and they belong to the *entry*, not to a
/// note that happens to mention it. Deleting a note must never take the evidence
/// of what a trade looked like with it.
///
/// Staging, the markdown form and the rendering are shared with
/// [NoteAttachments] so a body written in either editor renders identically.
/// Only the store differs, which is the one thing that has to differ: the
/// backend gives journal files their own bucket and their own row-level policy.
class JournalAttachments {
  const JournalAttachments._();

  static Future<String> _url(String ref) =>
      JournalRepositoryScope.repository.resolveAttachmentUrl(ref);

  /// Copies [source] out of the OS cache, stores it against [entryId] and
  /// returns the markdown to drop at the cursor.
  ///
  /// [entryId] must already exist — an attachment uploaded against an unsaved
  /// draft would have no owner, so callers save first.
  static Future<String> attach({
    required String entryId,
    required File source,
    required String filename,
  }) async {
    final File staged = await NoteAttachments.stage(source);
    final String ref = await JournalRepositoryScope.repository.uploadAttachment(
      entryId,
      staged,
      filename: filename,
    );
    return NoteAttachments.markdownFor(
      ref: ref,
      filename: filename,
      isImage: NoteAttachments.isImageFile(staged.path),
    );
  }

  /// Removes an attachment from the private bucket and clears its entry attachment record.
  static Future<void> delete(String storagePath) =>
      JournalRepositoryScope.repository.deleteAttachment(storagePath);

  /// Wire into `RichMarkdownPreview.imageResolver`.
  static Widget resolve(BuildContext context, Uri uri) =>
      NoteAttachments.resolve(context, uri, using: _url);

  /// Wire into `MarkdownPdfExporter.exportAndShare`'s `imageResolver`.
  static Future<Uint8List?> bytesFor(Uri uri) =>
      NoteAttachments.bytesFor(uri, using: _url);
}
