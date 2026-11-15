import 'package:tradex/core/config/supabase_config.dart';
import 'package:tradex/core/config/supabase_storage_egress.dart';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:tradex/core/flutter-ui/flutter_ui.dart';
import 'package:uuid/uuid.dart';

import 'notes_repository.dart';

/// Turns a stored attachment reference into something loadable.
///
/// Every repository that owns files exposes one of these, and the resolver is
/// passed in rather than looked up so a journal entry's screenshot resolves out
/// of the journal's bucket while a note's resolves out of the notes bucket. The
/// markdown, the preview and the PDF exporter are identical either way.
typedef AttachmentUrlResolver = Future<String> Function(String ref);

/// How a note refers to a file it owns.
///
/// The body stores an opaque repository reference behind the `local-image://` /
/// `local-file://` schemes — never a device path the writer could not move, and
/// never a signed URL that expires. Turning a reference back into something
/// displayable is the repository's job, so the same note body renders
/// identically against the demo store and against Supabase Storage.
class NoteAttachments {
  const NoteAttachments._();

  static const String imageScheme = 'local-image';
  static const String fileScheme = 'local-file';
  static const Uuid _uuid = Uuid();

  /// Resolved references, so scrolling a note with ten screenshots in it does
  /// not re-issue ten signed-URL requests on every rebuild.
  static final Map<String, ({String url, DateTime expires})> _resolved = {};
  static String _cacheKey(String ref, AttachmentUrlResolver? resolver) =>
      '${SupabaseConfig.client?.auth.currentUser?.id ?? 'signedout'}:${identityHashCode(resolver ?? NotesRepositoryScope.repository)}:$ref';
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
    final cacheTtl =
        SupabaseStorageEgress.noteAttachments.clientUrlCacheTtl ??
        const Duration(minutes: 50);
    _resolved[key] = (
      url: url,
      expires: DateTime.now().add(cacheTtl),
    );
  }

  /// Clears all cached signed URLs. Called on logout or account switch.
  static void clearCache() => _resolved.clear();

  /// Invalidates cache entries referencing [ref].
  static void invalidate(String ref) {
    _resolved.removeWhere((k, _) => k.contains(ref));
  }

  /// Invalidates all cached attachments for a given note.
  static void invalidateForNote(String noteId) {
    _resolved.removeWhere((k, _) => k.contains(noteId));
  }

  /// Deletes an attachment from private storage and purges cache.
  static Future<void> delete(
    String storagePath, {
    Future<void> Function(String)? using,
  }) async {
    invalidate(storagePath);
    if (using != null) {
      await using(storagePath);
    } else {
      await NotesRepositoryScope.repository.deleteAttachment(storagePath);
    }
  }

  /// Copies [source] into the app's own attachments directory under a name that
  /// cannot collide and contains no spaces. Pickers hand back paths inside a
  /// cache the OS may purge at will; a note that outlives the session needs its
  /// own copy of the bytes.
  static Future<File> stage(File source) async {
    final Directory docs = await getApplicationDocumentsDirectory();
    final Directory dir = Directory(p.join(docs.path, 'note_attachments'));
    if (!dir.existsSync()) await dir.create(recursive: true);
    return source.copy(
      p.join(dir.path, '${_uuid.v4()}${p.extension(source.path)}'),
    );
  }

  /// Uploads [bytes] directly and returns the markdown to drop at the cursor.
  /// Works across all platforms including Web without staging to disk.
  static Future<String> attachBytes({
    required String noteId,
    required Uint8List bytes,
    required String filename,
  }) async {
    final String ref = await NotesRepositoryScope.repository.uploadAttachment(
      noteId,
      null,
      bytes: bytes,
      filename: filename,
    );
    return markdownFor(
      ref: ref,
      filename: filename,
      isImage: isImageFile(filename),
    );
  }

  /// The markdown to drop at the cursor for a stored [ref].
  static String markdownFor({
    required String ref,
    required String filename,
    required bool isImage,
  }) => isImage
      ? '![$filename]($imageScheme://$ref)\n'
      : '[$filename]($fileScheme://$ref)\n';

  /// The repository reference inside an attachment URI, or null for anything
  /// else — an ordinary `https://` image somebody pasted, say.
  /// Legacy Supabase Storage URLs pointing to private buckets
  /// (`strategy-attachments`, `journal-attachments`, `note-attachments`) are
  /// also extracted so they route through authorized signed-URL resolution.
  static String? refOf(Uri uri) {
    if (uri.scheme == imageScheme || uri.scheme == fileScheme) {
      final host = uri.host;
      final path = uri.path;
      if (host.isEmpty) return path;
      if (path.isEmpty) return host;
      return path.startsWith('/') ? '$host$path' : '$host/$path';
    }
    if (uri.scheme == 'http' || uri.scheme == 'https') {
      final segments = uri.pathSegments;
      const privateBuckets = <String>{
        'strategy-attachments',
        'journal-attachments',
        'note-attachments',
      };
      for (var i = 0; i < segments.length - 1; i++) {
        if (privateBuckets.contains(segments[i])) {
          final extracted = segments.sublist(i + 1).join('/');
          if (extracted.isNotEmpty) return extracted;
        }
      }
      return null;
    }
    // Also support relative references or path-only markdown images
    if (uri.scheme.isEmpty &&
        uri.path.isNotEmpty &&
        !uri.path.startsWith('http')) {
      return uri.path;
    }
    return null;
  }

  /// Extracts all owned attachment references (`local-image://`, `local-file://`,
  /// or private storage bucket URLs) present in [markdown].
  static Set<String> extractRefs(String markdown) {
    if (markdown.isEmpty) return const <String>{};
    final refs = <String>{};
    final pattern = RegExp(r'!?\[[^\]]*\]\(([^)\s]+)\)');
    for (final match in pattern.allMatches(markdown)) {
      final raw = match.group(1)?.trim();
      if (raw == null || raw.isEmpty) continue;
      final uri = Uri.tryParse(raw);
      if (uri == null) continue;
      if (uri.scheme == imageScheme ||
          uri.scheme == fileScheme ||
          uri.scheme == 'http' ||
          uri.scheme == 'https') {
        final ref = refOf(uri);
        if (ref != null && ref.isNotEmpty) {
          refs.add(ref);
        }
      }
    }
    return refs;
  }

  static bool isImageFile(String path) => const <String>[
    '.png',
    '.jpg',
    '.jpeg',
    '.gif',
    '.webp',
    '.bmp',
  ].contains(p.extension(path).toLowerCase());

  /// Wire straight into `RichMarkdownPreview.imageResolver`. It is called for
  /// every image in the document, so it covers all three states one can be in:
  /// an attachment this app stored, a plain remote URL, and unreadable.
  ///
  /// [using] overrides which store the reference is read from; it defaults to
  /// the notes repository, which is what a note's own body wants.
  static Widget resolve(
    BuildContext context,
    Uri uri, {
    AttachmentUrlResolver? using,
  }) {
    final String? ref = refOf(uri);
    if (ref == null) {
      final bool remote = uri.scheme == 'http' || uri.scheme == 'https';
      return remote
          ? _framed(UiRemoteImage(url: uri.toString(), fit: BoxFit.contain))
          : _broken(context, 'That image link cannot be opened');
    }
    final String key = _cacheKey(ref, using);
    final String? cached = _cached(key);
    if (cached != null) return _framed(_bytes(context, cached));

    return FutureBuilder<String>(
      future: (using ?? NotesRepositoryScope.repository.resolveAttachmentUrl)(
        ref,
      ),
      builder: (BuildContext ctx, AsyncSnapshot<String> snap) {
        if (snap.connectionState != ConnectionState.done) {
          return _framed(UiSkeleton(height: ctx.sz(180)));
        }
        final String? url = snap.data;
        if (snap.hasError || url == null || url.isEmpty) {
          return _broken(ctx, 'This attachment is no longer available');
        }
        _remember(key, url);
        return _framed(_bytes(ctx, url));
      },
    );
  }

  /// Raw bytes for an attachment, for consumers that cannot host a widget —
  /// [MarkdownPdfExporter.exportAndShare]'s `imageResolver`, chiefly. Returns
  /// null for anything unreachable; the caller drops the image rather than
  /// failing the export.
  static Future<Uint8List?> bytesFor(
    Uri uri, {
    AttachmentUrlResolver? using,
  }) async {
    final String? ref = refOf(uri);
    String source = uri.toString();
    if (ref != null) {
      final cached = _cached(_cacheKey(ref, using));
      if (cached != null) {
        source = cached;
      } else {
        try {
          source = await (using ??
              NotesRepositoryScope.repository.resolveAttachmentUrl)(ref);
        } catch (_) {
          // Skip unresolvable/unauthorized attachments so PDF export continues gracefully.
          return null;
        }
      }
      if (source.isEmpty) return null;
      _remember(_cacheKey(ref, using), source);
    }
    final Uri? resolved = Uri.tryParse(source);
    if (resolved != null &&
        (resolved.scheme == 'https' || resolved.scheme == 'http')) {
      return _download(resolved);
    }
    // Markdown paths are untrusted. Only repository references may resolve to
    // local images, and those must remain inside the app's staged attachments.
    if (ref == null) return null;
    return _localBytes(source);
  }

  static Future<Uint8List?> _localBytes(String source) async {
    try {
      final Directory docs = await getApplicationDocumentsDirectory();
      final Directory root = Directory(p.join(docs.path, 'note_attachments'));
      final String boundary = await root.resolveSymbolicLinks();
      final resolved = Uri.tryParse(source);
      final File file = resolved?.scheme == 'file'
          ? File.fromUri(resolved!)
          : File(source);
      if (await file.exists()) {
        final String canonical = await file.resolveSymbolicLinks();
        if (p.isWithin(boundary, canonical)) {
          return await file.readAsBytes();
        }
      }
      // Check if staged filename matches in note_attachments directory
      final String name = p.basename(source);
      final File fallback = File(p.join(root.path, name));
      if (await fallback.exists()) {
        final String canonical = await fallback.resolveSymbolicLinks();
        if (p.isWithin(boundary, canonical)) {
          return await fallback.readAsBytes();
        }
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  static Future<Uint8List?> _download(Uri uri) async {
    final HttpClient client = HttpClient();
    try {
      final HttpClientResponse response = await (await client.getUrl(
        uri,
      )).close();
      if (response.statusCode != 200) return null;
      final BytesBuilder buffer = BytesBuilder(copy: false);
      await response.forEach(buffer.add);
      return buffer.takeBytes();
    } catch (_) {
      return null;
    } finally {
      client.close();
    }
  }

  static Widget _bytes(BuildContext context, String source) {
    if (source.startsWith('http')) {
      return UiRemoteImage(url: source, fit: BoxFit.contain);
    }
    return FutureBuilder<Uint8List?>(
      future: _localBytes(source),
      builder: (context, snapshot) {
        final bytes = snapshot.data;
        if (bytes == null) {
          return _broken(
            context,
            'This attachment is unavailable or outside app storage',
          );
        }
        return Image.memory(
          bytes,
          fit: BoxFit.contain,
          errorBuilder: (context, error, stack) =>
              _broken(context, 'This attachment could not be decoded'),
        );
      },
    );
  }

  /// Attachments are full-bleed inside the note column with the same rounding
  /// the rest of the design system uses, and capped in height so one screenshot
  /// cannot push the whole note off screen.
  static Widget _framed(Widget child) => Builder(
    builder: (BuildContext context) => Padding(
      padding: EdgeInsets.symmetric(
        vertical: context.sp(context.ui.spacing.sm),
      ),
      child: ClipRRect(
        borderRadius: context.radius(context.ui.radii.lg),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: context.sz(420)),
          child: child,
        ),
      ),
    ),
  );

  static Widget _broken(BuildContext context, String message) => Padding(
    padding: EdgeInsets.symmetric(vertical: context.sp(context.ui.spacing.sm)),
    child: UiCallout(
      title: 'Attachment missing',
      message: message,
      intent: UiIntent.warning,
      icon: Icons.broken_image_outlined,
    ),
  );
}
