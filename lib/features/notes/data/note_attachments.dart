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
  static final Map<String, String> _resolved = <String, String>{};

  /// Copies [source] into the app's own attachments directory under a name that
  /// cannot collide and contains no spaces. Pickers hand back paths inside a
  /// cache the OS may purge at will; a note that outlives the session needs its
  /// own copy of the bytes.
  static Future<File> stage(File source) async {
    final Directory docs = await getApplicationDocumentsDirectory();
    final Directory dir = Directory(p.join(docs.path, 'note_attachments'));
    if (!dir.existsSync()) await dir.create(recursive: true);
    return source.copy(p.join(dir.path, '${_uuid.v4()}${p.extension(source.path)}'));
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
  static String? refOf(Uri uri) =>
      uri.scheme == imageScheme || uri.scheme == fileScheme
      ? '${uri.host}${uri.path}'
      : null;

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
    final String? cached = _resolved[ref];
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
        _resolved[ref] = url;
        return _framed(_bytes(ctx, url));
      },
    );
  }

  /// Raw bytes for an attachment, for consumers that cannot host a widget —
  /// [MarkdownPdfExporter.exportAndShare]'s `imageResolver`, chiefly. Returns
  /// null for anything unreachable; the caller drops the image rather than
  /// failing the export.
  static Future<Uint8List?> bytesFor(Uri uri, {AttachmentUrlResolver? using}) async {
    final String? ref = refOf(uri);
    String source = uri.toString();
    if (ref != null) {
      source =
          _resolved[ref] ??
          await (using ??
              NotesRepositoryScope.repository.resolveAttachmentUrl)(ref);
      if (source.isEmpty) return null;
      _resolved[ref] = source;
    }
    if (source.startsWith('http')) return _download(Uri.parse(source));
    final File file = File(source);
    return file.existsSync() ? file.readAsBytes() : null;
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
    final File file = File(source);
    if (!file.existsSync()) {
      return _broken(context, 'This attachment was moved or deleted');
    }
    return Image.file(
      file,
      fit: BoxFit.contain,
      errorBuilder: (BuildContext ctx, Object _, StackTrace? _) =>
          _broken(ctx, 'This attachment could not be decoded'),
    );
  }

  /// Attachments are full-bleed inside the note column with the same rounding
  /// the rest of the design system uses, and capped in height so one screenshot
  /// cannot push the whole note off screen.
  static Widget _framed(Widget child) => Builder(
    builder: (BuildContext context) => Padding(
      padding: EdgeInsets.symmetric(vertical: context.sp(context.ui.spacing.sm)),
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
