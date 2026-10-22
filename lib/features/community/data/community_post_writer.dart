import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:tradex/core/data/owned_record_writer.dart';
import 'package:tradex/features/community/models/community_models.dart';

/// Creates a private draft, writes its children, then publishes the complete post.
class CommunityPostWriter {
  CommunityPostWriter(this.client, this.actorId);
  final SupabaseClient client;
  final String actorId;

  Future<void> create(CommunityPost post) async {
    if (actorId.isEmpty) throw StateError('Sign in to publish a post.');
    if (post.scheduledFor != null) {
      throw StateError(
        'Scheduled publishing requires the publishing service. Your draft has been kept.',
      );
    }
    if (post.replyAudience != CommunityReplyAudience.everyone) {
      throw StateError(
        'Restricted replies require server enforcement. Your draft has been kept.',
      );
    }
    if (post.poll?.allowMultiple == true) {
      throw StateError(
        'Multiple-choice voting requires server support. Your draft has been kept.',
      );
    }
    var inserted = false;
    try {
      await client
          .from('community_posts')
          .insert({
            'id': post.id,
            'author_id': actorId,
            'body': post.quoted == null
                ? post.body
                : '${post.body}\n\nQuoted post: /community?post=${Uri.encodeQueryComponent(post.quoted!.id)}',
            'title': post.tickers.isEmpty ? 'Post' : post.tickers.first,
            'kind': post.poll != null
                ? 'poll'
                : post.tradeSetup != null
                ? 'signal'
                : 'standard',
            'tickers': post.tickers,
            'tags': post.tags,
            'is_public': false,
            'visibility': 'private',
          })
          .select('id')
          .single();
      inserted = true;
      await writeChildren(post);
      await OwnedRecordWriter(
        client: client,
        actorId: actorId,
      ).update('community_posts', post.id, {
        'is_public': post.isPublic,
        'visibility': post.isPublic ? 'public' : 'private',
      }, ownerColumn: 'author_id');
    } catch (_) {
      if (inserted) {
        try {
          await OwnedRecordWriter(
            client: client,
            actorId: actorId,
          ).delete('community_posts', post.id, ownerColumn: 'author_id');
        } catch (_) {
          /* Retained draft stays private. */
        }
      }
      rethrow;
    }
  }

  Future<void> writeChildren(CommunityPost post) async {
    final setup = post.tradeSetup;
    if (setup != null) {
      final entry = double.tryParse(setup.entry);
      final stop = double.tryParse(setup.stopLoss ?? '');
      final target = double.tryParse(setup.target ?? '');
      if (entry == null ||
          !entry.isFinite ||
          entry <= 0 ||
          stop == null ||
          !stop.isFinite ||
          stop <= 0 ||
          target == null ||
          !target.isFinite ||
          target <= 0) {
        throw StateError('Enter positive entry, stop-loss and target prices.');
      }
      await client.from('community_post_trade_setups').upsert({
        'post_id': post.id,
        'ticker': setup.ticker,
        'side': setup.side.toLowerCase(),
        'entry': entry,
        'stop_loss': double.tryParse(setup.stopLoss ?? ''),
        'target1': double.tryParse(setup.target ?? ''),
      }, onConflict: 'post_id');
    }
    for (final url in post.effectiveImageUrls) {
      await client.from('community_post_attachments').insert({
        'post_id': post.id,
        'kind': 'image',
        'ref_id': url,
        'url': url,
        'title': 'Chart image',
      });
    }
    final attachment = post.attachment;
    if (attachment != null) {
      await client.from('community_post_attachments').insert({
        'post_id': post.id,
        'kind': attachment.source.kind.name,
        'ref_id': attachment.source.id,
        'title': attachment.source.title,
      });
    }
    final poll = post.poll;
    if (poll != null) {
      final saved = await client
          .from('community_polls')
          .insert({
            'post_id': post.id,
            'question': poll.question,
            'expires_at': poll.expiresAt?.toIso8601String(),
          })
          .select('id')
          .single();
      await client.from('community_poll_options').insert([
        for (final option in poll.options)
          {'poll_id': saved['id'], 'option_text': option.text},
      ]);
    }
  }
}
