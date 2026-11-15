import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// How each Supabase Storage bucket serves media across Egress vs Cached Egress.
enum SupabaseEgressTier {
  /// Public buckets (`avatars`, `community-attachments`) served over static
  /// `/storage/v1/object/public/...` URLs with immutable filenames and long
  /// `Cache-Control` TTLs so Supabase Smart CDN serves cache hits via
  /// **Cached Egress** instead of hammering origin storage.
  cachedPublicCdn,

  /// Private buckets (`journal-attachments`, `note-attachments`,
  /// `strategy-attachments`) enforced by Postgres RLS and accessed via
  /// time-limited `/storage/v1/object/sign/...` URLs (**Direct Egress**).
  privateSignedDirect,

  /// Private end-to-end encrypted blobs (`chat-attachments/*.enc`) downloaded
  /// through authenticated `.download()` (**Direct Egress**) and decrypted strictly
  /// on participant devices with session-scoped memory caching.
  privateEncryptedDirect,
}

@immutable
class StorageBucketEgressPolicy {
  const StorageBucketEgressPolicy({
    required this.bucketId,
    required this.tier,
    required this.uploadCacheControl,
    this.signedUrlTtlSeconds,
    this.clientUrlCacheTtl,
    required this.isPublicBucket,
    required this.rationale,
  });

  final String bucketId;
  final SupabaseEgressTier tier;

  /// `cacheControl` max-age header (in seconds as expected by `FileOptions`)
  /// written alongside uploaded objects.
  final String uploadCacheControl;

  /// Expiration window for private signed URLs, or `null` for public CDN buckets.
  final int? signedUrlTtlSeconds;

  /// In-memory client cache lifetime to avoid rotating `?token=` parameters
  /// prematurely and causing redundant uncached Egress misses.
  final Duration? clientUrlCacheTtl;

  final bool isPublicBucket;
  final String rationale;
}

/// Central Supabase Egress vs Cached Egress routing policy for every storage
/// bucket and URL resolver in TradeX.
class SupabaseStorageEgress {
  const SupabaseStorageEgress._();

  /// 1 year (`31536000s`) for content-hashed (`sha256`) and timestamp-versioned
  /// immutable public assets.
  static const String immutableCdnCacheControl = '31536000';

  static const StorageBucketEgressPolicy avatars = StorageBucketEgressPolicy(
    bucketId: 'avatars',
    tier: SupabaseEgressTier.cachedPublicCdn,
    uploadCacheControl: immutableCdnCacheControl,
    isPublicBucket: true,
    rationale:
        'Timestamped public profile photos fetched repeatedly in feeds, threads, and OG cards -> Smart CDN Cached Egress.',
  );

  static const StorageBucketEgressPolicy communityAttachments =
      StorageBucketEgressPolicy(
        bucketId: 'community-attachments',
        tier: SupabaseEgressTier.cachedPublicCdn,
        uploadCacheControl: immutableCdnCacheControl,
        isPublicBucket: true,
        rationale:
            'SHA-256 content-addressed public post media shared across feed visitors & social bots -> Smart CDN Cached Egress.',
      );

  static const StorageBucketEgressPolicy journalAttachments =
      StorageBucketEgressPolicy(
        bucketId: 'journal-attachments',
        tier: SupabaseEgressTier.privateSignedDirect,
        uploadCacheControl: '3600',
        signedUrlTtlSeconds: 3600,
        clientUrlCacheTtl: Duration(minutes: 50),
        isPublicBucket: false,
        rationale:
            'Private P&L charts & trade receipts protected by owner RLS -> 1h signed Direct Egress with 50m session URL reuse.',
      );

  static const StorageBucketEgressPolicy noteAttachments =
      StorageBucketEgressPolicy(
        bucketId: 'note-attachments',
        tier: SupabaseEgressTier.privateSignedDirect,
        uploadCacheControl: '3600',
        signedUrlTtlSeconds: 3600,
        clientUrlCacheTtl: Duration(minutes: 50),
        isPublicBucket: false,
        rationale:
            'Private & toggled-public research note attachments protected by RLS -> 1h signed Direct Egress with 50m session URL reuse.',
      );

  static const StorageBucketEgressPolicy strategyAttachments =
      StorageBucketEgressPolicy(
        bucketId: 'strategy-attachments',
        tier: SupabaseEgressTier.privateSignedDirect,
        uploadCacheControl: '300',
        signedUrlTtlSeconds: 300,
        clientUrlCacheTtl: Duration(minutes: 4),
        isPublicBucket: false,
        rationale:
            'Proprietary playbook setups supporting fast public-to-private revocation -> 5m signed Direct Egress matched with 4m client cache.',
  );

  static const StorageBucketEgressPolicy chatAttachments =
      StorageBucketEgressPolicy(
        bucketId: 'chat-attachments',
        tier: SupabaseEgressTier.privateEncryptedDirect,
        uploadCacheControl: '300',
        signedUrlTtlSeconds: 300,
        isPublicBucket: false,
        rationale:
            'Zero-knowledge E2EE .enc attachments downloaded once per device session (Direct Egress) & legacy 5m signed URLs.',
      );

  static const List<StorageBucketEgressPolicy> allPolicies =
      <StorageBucketEgressPolicy>[
        avatars,
        communityAttachments,
        journalAttachments,
        noteAttachments,
        strategyAttachments,
        chatAttachments,
      ];

  static final Map<String, StorageBucketEgressPolicy> _byBucket =
      <String, StorageBucketEgressPolicy>{
        for (final p in allPolicies) p.bucketId: p,
      };

  static StorageBucketEgressPolicy? policyForBucket(String bucketId) =>
      _byBucket[bucketId.trim()];

  /// Extracts a clean relative object path inside [bucket] when [ref] points to
  /// a relative key, `<bucket>/<key>`, or a Supabase Storage URL
  /// (`/storage/v1/object/{public|sign|authenticated}/<bucket>/<key>?...`).
  ///
  /// Returns `null` for `data:`, `file:`, local paths, or external third-party
  /// HTTP(S) URLs that do not belong to Supabase Storage [bucket].
  static String? extractStoragePath(
    String ref, {
    required String bucket,
  }) {
    final trimmed = ref.trim();
    if (trimmed.isEmpty ||
        trimmed.startsWith('data:') ||
        trimmed.startsWith('file:') ||
        trimmed.startsWith('/') ||
        trimmed.contains(':\\')) {
      return null;
    }

    var candidate = trimmed;
    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
      final uri = Uri.tryParse(trimmed);
      if (uri == null) return null;
      final segments = uri.pathSegments;
      final storageObjIdx = _findBucketMarkerIndex(segments, bucket);
      if (storageObjIdx == -1 || storageObjIdx >= segments.length - 1) {
        return null;
      }
      candidate = segments.sublist(storageObjIdx + 1).join('/');
    }

    if (candidate.contains('?')) {
      candidate = candidate.split('?').first;
    }
    final prefix = '$bucket/';
    if (candidate.startsWith(prefix)) {
      candidate = candidate.substring(prefix.length);
    }
    while (candidate.startsWith('/')) {
      candidate = candidate.substring(1);
    }
    if (candidate.isEmpty || candidate.contains('..')) return null;
    return candidate;
  }

  static int _findBucketMarkerIndex(List<String> segments, String bucket) {
    for (int i = 0; i < segments.length; i++) {
      if (segments[i] == bucket) {
        // Require Supabase Storage URL shape (`/storage/v1/object/.../<bucket>/...`)
        // or `/storage/v1/render/image/.../<bucket>/...`.
        if (i >= 1 &&
            (segments.contains('storage') && segments.contains('object') ||
                segments.contains('render'))) {
          return i;
        }
      }
    }
    return -1;
  }

  /// Pure URL normalizer for **Cached Egress** public buckets (`avatars`,
  /// `community-attachments`). Upgrades relative keys or legacy signed URLs to
  /// `<supabaseUrl>/storage/v1/object/public/<bucket>/<key>`, while passing
  /// third-party URLs and local/data URIs through unchanged.
  static String normalizePublicStorageUrl({
    required String supabaseUrl,
    required String bucket,
    required String ref,
  }) {
    final policy = policyForBucket(bucket);
    if (policy == null || !policy.isPublicBucket) {
      throw ArgumentError.value(
        bucket,
        'bucket',
        'normalizePublicStorageUrl can only be used for public Smart CDN buckets.',
      );
    }
    final cleanPath = extractStoragePath(ref, bucket: bucket);
    if (cleanPath == null) return ref;
    final cleanBase = supabaseUrl.trim().replaceFirst(RegExp(r'/+$'), '');
    if (cleanBase.isEmpty) return ref;
    return '$cleanBase/storage/v1/object/public/$bucket/$cleanPath';
  }

  /// Resolves [ref] through `client.storage.from(bucket).getPublicUrl(...)` so
  /// all public bucket assets (`avatars`, `community-attachments`) serve over
  /// static Smart CDN URLs (**Cached Egress**), even if a legacy signed URL or
  /// `<bucket>/...` prefix was stored.
  static String resolvePublicCdnUrl({
    required SupabaseClient client,
    required String bucket,
    required String ref,
  }) {
    final policy = policyForBucket(bucket);
    if (policy == null || !policy.isPublicBucket) {
      throw ArgumentError.value(
        bucket,
        'bucket',
        'resolvePublicCdnUrl can only be used for public Smart CDN buckets.',
      );
    }
    final cleanPath = extractStoragePath(ref, bucket: bucket);
    if (cleanPath == null) return ref;
    return client.storage.from(bucket).getPublicUrl(cleanPath);
  }
}
