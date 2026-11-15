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

  /// Resolves a sanitized `ax_silent_nav` cookie payload (`1|<key>|<label>`)
  /// for a destination [url] so the incoming document renders the matching
  /// full-screen skeleton loader and highlighted mobile dock slot immediately.
  static String silentNavValueForUrl(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null) return '1';
    final host = uri.host.toLowerCase();
    final seg = uri.pathSegments.isEmpty
        ? ''
        : uri.pathSegments.first.toLowerCase();

    String key = '';
    String label = '';

    if (seg == 'community_explore' || seg == 'explore') {
      key = 'community_explore';
      label = 'Explore';
    } else if (seg == 'community_network' ||
        seg == 'community_follow' ||
        seg == 'network') {
      key = 'community_network';
      label = 'Network';
    } else if (seg == 'community_profile' ||
        seg == 'profile' ||
        seg.startsWith('@')) {
      key = 'community_profile';
      label = 'Profile';
    } else if (seg == 'community_feed') {
      key = 'community_feed';
      label = 'Community';
    } else if (seg == 'market' || seg.startsWith('market_')) {
      key = 'market';
      label = 'Markets';
    } else if (seg == 'journal') {
      key = 'journal';
      label = 'Journal';
    } else if (seg == 'strategies' || seg == 'strategy') {
      key = 'strategies';
      label = 'Strategies';
    } else if (seg == 'notes' || seg == 'note') {
      key = 'notes';
      label = 'Notes';
    } else if (seg == 'calculators' || seg == 'calculator') {
      key = 'calculators';
      label = 'Calculators';
    } else if (seg == 'messages' || seg == 'message' || seg == 'thread') {
      key = 'messages';
      label = 'Messages';
    } else if (seg == 'ai_copilot' || seg == 'ai' || seg == 'copilot') {
      key = 'ai_copilot';
      label = 'AI Copilot';
    } else if (seg.startsWith('settings')) {
      key = 'settings';
      label = 'Settings';
    } else if (seg == 'referrals') {
      key = 'referrals';
      label = 'Referrals';
    } else if (seg == 'marketing') {
      key = 'marketing';
      label = 'Media Kit';
    } else if (seg == 'payouts') {
      key = 'payouts';
      label = 'Payouts';
    } else if (seg == 'org_team') {
      key = 'org_team';
      label = 'Users';
    } else if (seg == 'affiliate_reviews') {
      key = 'affiliate_reviews';
      label = 'Affiliates';
    } else if (seg.startsWith('org_') || seg.startsWith('admin')) {
      key = 'admin_console';
      label = 'Admin Console';
    } else if (host.startsWith('community.') ||
        seg.startsWith('community') ||
        seg == 'p' ||
        seg == 'posts' ||
        seg == 'post') {
      key = 'community_feed';
      label = 'Community';
    } else if (host.startsWith('affiliate.') || seg.startsWith('affiliate')) {
      key = 'partner_hub';
      label = 'Partner Hub';
    } else if (host.startsWith('admin.')) {
      key = 'admin_console';
      label = 'Admin Console';
    } else if (host.startsWith('app.') ||
        seg == 'workspace' ||
        seg == 'overview') {
      key = 'workspace';
      label = 'Workspace';
    }

    if (key.isEmpty || label.isEmpty) return '1';
    return '1|$key|$label';
  }
}
