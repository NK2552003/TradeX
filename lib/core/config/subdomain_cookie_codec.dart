/// Pure-Dart helpers for reading, chunking, and formatting cookies shared across
/// `alphajournal.in` and its subdomains (`app.`, `community.`, `affiliate.`,
/// `admin.`).
class SubdomainCookieCodec {
  const SubdomainCookieCodec._();

  static const String rootDomain = 'alphajournal.in';
  static const int maxChunkEncodedLength = 3000;
  static const int maxChunks = 16;

  /// Returns `true` when [host] belongs to the production `alphajournal.in`
  /// apex or one of its subdomains.
  static bool isProductionDomain(String host) {
    final normalized = host.trim().toLowerCase();
    return normalized == rootDomain || normalized.endsWith('.$rootDomain');
  }

  /// Parses `document.cookie` into decoded key-value pairs.
  static Map<String, String> parseCookieString(String rawCookie) {
    final result = <String, String>{};
    if (rawCookie.trim().isEmpty) return result;
    for (final part in rawCookie.split(';')) {
      final idx = part.indexOf('=');
      if (idx <= 0) continue;
      final name = part.substring(0, idx).trim();
      final rawValue = part.substring(idx + 1).trim();
      if (name.isEmpty) continue;
      try {
        result[name] = Uri.decodeComponent(rawValue);
      } catch (_) {
        result[name] = rawValue;
      }
    }
    return result;
  }

  /// Splits [value] into URI-encoded-safe slices so each cookie stays well
  /// under the browser 4096-byte per-cookie limit.
  static List<String> splitForCookies(
    String value, {
    int maxEncodedLength = maxChunkEncodedLength,
  }) {
    if (value.isEmpty) return const <String>[];
    final chunks = <String>[];
    final buffer = StringBuffer();
    var currentEncodedLength = 0;

    for (final rune in value.runes) {
      final ch = String.fromCharCode(rune);
      final encodedLen = Uri.encodeComponent(ch).length;
      if (currentEncodedLength > 0 &&
          currentEncodedLength + encodedLen > maxEncodedLength) {
        chunks.add(buffer.toString());
        buffer.clear();
        currentEncodedLength = 0;
      }
      buffer.write(ch);
      currentEncodedLength += encodedLen;
    }

    if (buffer.isNotEmpty) {
      chunks.add(buffer.toString());
    }
    return chunks;
  }

  /// Reads a chunked value stored under `<baseKey>.n` and `<baseKey>.0..n-1`.
  static String? readChunked(
    Map<String, String> cookies,
    String baseKey,
  ) {
    final countRaw = cookies['$baseKey.n'];
    if (countRaw == null || countRaw.isEmpty) return null;
    final count = int.tryParse(countRaw);
    if (count == null || count <= 0 || count > maxChunks) return null;
    final buffer = StringBuffer();
    for (var i = 0; i < count; i++) {
      final chunk = cookies['$baseKey.$i'];
      if (chunk == null) return null;
      buffer.write(chunk);
    }
    return buffer.toString();
  }

  /// Formats a single `Set-Cookie` assignment string for `document.cookie`.
  static String formatSetCookie(
    String name,
    String value, {
    String? domain,
    int? maxAgeSeconds,
    bool secure = true,
  }) {
    final parts = <String>[
      '$name=${Uri.encodeComponent(value)}',
      if (domain != null && domain.isNotEmpty) 'Domain=$domain',
      'Path=/',
      'SameSite=Lax',
      if (maxAgeSeconds != null) 'Max-Age=$maxAgeSeconds',
      if (secure) 'Secure',
    ];
    return parts.join('; ');
  }

  /// Formats an expired cookie directive to delete [name].
  static String formatDeleteCookie(
    String name, {
    String? domain,
    bool secure = true,
  }) {
    return formatSetCookie(
      name,
      '',
      domain: domain,
      maxAgeSeconds: 0,
      secure: secure,
    );
  }
}
