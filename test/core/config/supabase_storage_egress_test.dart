import 'package:flutter_test/flutter_test.dart';
import 'package:tradex/core/config/supabase_storage_egress.dart';
import 'package:tradex/core/flutter-ui/components/ui_remote_image.dart';

void main() {
  group('SupabaseStorageEgress policy matrix', () {
    test('classifies public CDN cached egress vs private direct egress buckets', () {
      expect(
        SupabaseStorageEgress.avatars.tier,
        SupabaseEgressTier.cachedPublicCdn,
      );
      expect(SupabaseStorageEgress.avatars.isPublicBucket, isTrue);
      expect(SupabaseStorageEgress.avatars.uploadCacheControl, '31536000');

      expect(
        SupabaseStorageEgress.communityAttachments.tier,
        SupabaseEgressTier.cachedPublicCdn,
      );
      expect(
        SupabaseStorageEgress.communityAttachments.isPublicBucket,
        isTrue,
      );
      expect(
        SupabaseStorageEgress.communityAttachments.uploadCacheControl,
        '31536000',
      );

      expect(
        SupabaseStorageEgress.journalAttachments.tier,
        SupabaseEgressTier.privateSignedDirect,
      );
      expect(SupabaseStorageEgress.journalAttachments.isPublicBucket, isFalse);
      expect(
        SupabaseStorageEgress.journalAttachments.signedUrlTtlSeconds,
        3600,
      );
      expect(
        SupabaseStorageEgress.journalAttachments.clientUrlCacheTtl,
        const Duration(minutes: 50),
      );

      expect(
        SupabaseStorageEgress.noteAttachments.tier,
        SupabaseEgressTier.privateSignedDirect,
      );
      expect(SupabaseStorageEgress.noteAttachments.isPublicBucket, isFalse);
      expect(SupabaseStorageEgress.noteAttachments.signedUrlTtlSeconds, 3600);

      expect(
        SupabaseStorageEgress.strategyAttachments.tier,
        SupabaseEgressTier.privateSignedDirect,
      );
      expect(SupabaseStorageEgress.strategyAttachments.isPublicBucket, isFalse);
      expect(
        SupabaseStorageEgress.strategyAttachments.signedUrlTtlSeconds,
        300,
      );
      expect(
        SupabaseStorageEgress.strategyAttachments.clientUrlCacheTtl,
        const Duration(minutes: 4),
      );

      expect(
        SupabaseStorageEgress.chatAttachments.tier,
        SupabaseEgressTier.privateEncryptedDirect,
      );
      expect(SupabaseStorageEgress.chatAttachments.isPublicBucket, isFalse);
    });

    test('normalizes public bucket paths and legacy signed URLs to Smart CDN public URLs', () {
      const baseUrl = 'https://xyz.supabase.co';

      expect(
        SupabaseStorageEgress.normalizePublicStorageUrl(
          supabaseUrl: baseUrl,
          bucket: 'community-attachments',
          ref: 'user-1/post-2/abc123.webp',
        ),
        'https://xyz.supabase.co/storage/v1/object/public/community-attachments/user-1/post-2/abc123.webp',
      );

      expect(
        SupabaseStorageEgress.normalizePublicStorageUrl(
          supabaseUrl: baseUrl,
          bucket: 'avatars',
          ref: 'https://xyz.supabase.co/storage/v1/object/sign/avatars/u1_123.webp?token=secret-jwt',
        ),
        'https://xyz.supabase.co/storage/v1/object/public/avatars/u1_123.webp',
      );

      expect(
        SupabaseStorageEgress.normalizePublicStorageUrl(
          supabaseUrl: baseUrl,
          bucket: 'avatars',
          ref: 'avatars/u1_123.webp',
        ),
        'https://xyz.supabase.co/storage/v1/object/public/avatars/u1_123.webp',
      );

      // External CDN & local URIs pass through unaltered.
      expect(
        SupabaseStorageEgress.normalizePublicStorageUrl(
          supabaseUrl: baseUrl,
          bucket: 'community-attachments',
          ref: 'https://images.unsplash.com/photo-123',
        ),
        'https://images.unsplash.com/photo-123',
      );
      expect(
        SupabaseStorageEgress.normalizePublicStorageUrl(
          supabaseUrl: baseUrl,
          bucket: 'avatars',
          ref: 'data:image/png;base64,AAA=',
        ),
        'data:image/png;base64,AAA=',
      );

      // Refuses private buckets from being normalized as public CDN URLs.
      expect(
        () => SupabaseStorageEgress.normalizePublicStorageUrl(
          supabaseUrl: baseUrl,
          bucket: 'journal-attachments',
          ref: 'u1/entry/chart.png',
        ),
        throwsArgumentError,
      );
    });

    test('UiRemoteImage.resizeImageUrl upgrades legacy signed URLs only for public buckets', () {
      expect(
        UiRemoteImage.resizeImageUrl(
          'https://xyz.supabase.co/storage/v1/object/sign/avatars/u1_99.webp?token=jwt123',
        ),
        'https://xyz.supabase.co/storage/v1/object/public/avatars/u1_99.webp',
      );

      expect(
        UiRemoteImage.resizeImageUrl(
          'https://xyz.supabase.co/storage/v1/object/sign/community-attachments/u1/p1/hash.png?token=jwt123',
          targetWidthPx: 400,
        ),
        'https://xyz.supabase.co/storage/v1/object/public/community-attachments/u1/p1/hash.png',
      );

      const privateJournalUrl =
          'https://xyz.supabase.co/storage/v1/object/sign/journal-attachments/u1/e1/chart.png?token=private-jwt';
      expect(
        UiRemoteImage.resizeImageUrl(privateJournalUrl, targetWidthPx: 400),
        privateJournalUrl,
      );
    });
  });
}
