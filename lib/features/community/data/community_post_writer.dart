import 'dart:convert';
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
    var inserted = false;
    try {
      final row = {
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
        'moderation_status': 'approved',
      };

      try {
        await client
            .from('community_posts')
            .insert({...row, 'moderation_status': 'approved'})
            .select('id')
            .single();
      } catch (_) {
        await client.from('community_posts').insert(row).select('id').single();
      }
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

  static Map<String, dynamic> candleAttachment(
    String postId,
    CommunityTradeSetup setup,
  ) => {
    'post_id': postId,
    'kind': 'chart_candles',
    'ref_id': setup.ticker,
    'title': setup.candlesFromImage
        ? 'Image-derived candles (approximate)'
        : 'Candlestick Chart Data',
    'url': jsonEncode([
      for (final candle in setup.candles)
        {
          'time': candle.time.toIso8601String(),
          'open': candle.open,
          'high': candle.high,
          'low': candle.low,
          'close': candle.close,
          'volume': candle.volume,
        },
    ]),
  };

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
      if (setup.candles.isNotEmpty) {
        await client
            .from('community_post_attachments')
            .insert(candleAttachment(post.id, setup));
      }
    }
    if (post.effectiveImageUrls.isNotEmpty) {
      await client.from('community_post_attachments').insert([
        for (final url in post.effectiveImageUrls.toSet())
          {
            'post_id': post.id,
            'kind': 'image',
            'ref_id': url,
            'url': url,
            'title': 'Chart image',
          },
      ]);
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
      final uuidPattern = RegExp(
        r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
      );
      final saved = await client
          .from('community_polls')
          .insert({
            if (uuidPattern.hasMatch(poll.id)) 'id': poll.id,
            'post_id': post.id,
            'question': poll.question,
            'expires_at': poll.expiresAt?.toIso8601String(),
          })
          .select('id')
          .single();
      final pollId = saved['id'] ?? poll.id;
      await client.from('community_poll_options').insert([
        for (final option in poll.options)
          {
            if (uuidPattern.hasMatch(option.id)) 'id': option.id,
            'poll_id': pollId,
            'option_text': option.text,
          },
      ]);
    }
  }
}
