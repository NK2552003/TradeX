import 'package:flutter/foundation.dart';
import 'package:tradex/core/app-ui/app_ui.dart';
import 'package:tradex/core/config/supabase_config.dart';
import 'package:tradex/core/data/demo_data_source.dart';

abstract class SupabasePostRepository {
  Future<List<AppPost>> getPosts();
  Future<AppPost> createPost({
    required String content,
    String? ticker,
    String? imageUrl,
  });
  Future<void> likePost(String postId);
  Future<List<AppComment>> getComments(String postId);
  Future<void> commentPost(String postId, String commentText);
  Future<void> savePost(String postId);
  Future<void> incrementView(String postId);
  Future<void> blockUser(String userIdToBlock);
}

class SupabasePostRepositoryImpl implements SupabasePostRepository {
  SupabasePostRepositoryImpl._();

  static final SupabasePostRepositoryImpl instance =
      SupabasePostRepositoryImpl._();

  factory SupabasePostRepositoryImpl() => instance;

  final DemoDataSource _demo = DemoDataSource.instance;

  @override
  Future<List<AppPost>> getPosts() async {
    if (SupabaseConfig.isConfigured) {
      try {
        final client = SupabaseConfig.client!;
        final user = client.auth.currentUser;
        if (user != null) {
          final blockedRes = await client
              .from('blocks')
              .select('blocked_id')
              .eq('blocker_id', user.id);

          final blockedIds = (blockedRes as List)
              .map((b) => b['blocked_id'] as String)
              .toSet();

          final res = await client
              .from('posts')
              .select('*, profiles!inner(handle, display_name, avatar_url)')
              .order('created_at', ascending: false);

          final filtered = (res as List)
              .where((row) => !blockedIds.contains(row['user_id']))
              .toList();

          return filtered.map((row) {
            final profile = row['profiles'] as Map<String, dynamic>?;
            final handle = profile?['handle'] as String? ?? 'trader';
            final name = profile?['display_name'] as String? ?? handle;

            return AppPost(
              id: row['id'] as String,
              author: AppTrader(
                id: row['user_id'] as String? ?? 'usr_trader',
                handle: handle,
                displayName: name,
                avatarUrl: profile?['avatar_url'] as String?,
              ),
              body: row['content'] as String? ?? '',
              createdAt: row['created_at'] != null
                  ? DateTime.parse(row['created_at'] as String)
                  : DateTime.now(),
              likes: 0,
              comments: 0,
              tickers: row['ticker'] != null
                  ? [row['ticker'] as String]
                  : const [],
              imageUrl: row['image_url'] as String?,
            );
          }).toList();
        }
      } catch (e) {
        debugPrint('[SupabasePostRepository] getPosts error: $e');
      }
    }
    return _demo.posts();
  }

  @override
  Future<AppPost> createPost({
    required String content,
    String? ticker,
    String? imageUrl,
  }) async {
    final now = DateTime.now();

    if (SupabaseConfig.isConfigured) {
      try {
        final client = SupabaseConfig.client!;
        final user = client.auth.currentUser;
        if (user != null) {
          final res = await client
              .from('posts')
              .insert({
                'user_id': user.id,
                'content': content,
                'ticker': ticker,
                'image_url': imageUrl,
              })
              .select('*, profiles!inner(handle, display_name, avatar_url)')
              .single();

          final profile = res['profiles'] as Map<String, dynamic>?;
          final handle = profile?['handle'] as String? ?? 'trader';
          final name = profile?['display_name'] as String? ?? handle;

          return AppPost(
            id: res['id'] as String,
            author: AppTrader(
              id: user.id,
              handle: handle,
              displayName: name,
              avatarUrl: profile?['avatar_url'] as String?,
            ),
            body: res['content'] as String? ?? '',
            createdAt: now,
            likes: 0,
            comments: 0,
            tickers: ticker != null ? [ticker] : const [],
            imageUrl: imageUrl,
          );
        }
      } catch (e) {
        debugPrint('[SupabasePostRepository] createPost error: $e');
      }
    }

    return AppPost(
      id: 'pst_${now.millisecondsSinceEpoch}',
      author: const AppTrader(
        id: 'usr_me',
        handle: 'nitish_trader',
        displayName: 'Nitish Kumar',
      ),
      body: content,
      createdAt: now,
      likes: 0,
      comments: 0,
      tickers: ticker != null ? [ticker] : const [],
      imageUrl: imageUrl,
    );
  }

  @override
  Future<void> likePost(String postId) async {
    if (SupabaseConfig.isConfigured) {
      try {
        final client = SupabaseConfig.client!;
        final user = client.auth.currentUser;
        if (user != null) {
          await client.from('likes').upsert({
            'user_id': user.id,
            'post_id': postId,
          });
        }
      } catch (e) {
        debugPrint('[SupabasePostRepository] likePost error: $e');
      }
    }
  }

  @override
  Future<void> commentPost(String postId, String commentText) async {
    if (SupabaseConfig.isConfigured) {
      try {
        final client = SupabaseConfig.client!;
        final user = client.auth.currentUser;
        if (user != null) {
          await client.from('comments').insert({
            'post_id': postId,
            'user_id': user.id,
            'content': commentText,
          });
        }
      } catch (e) {
        debugPrint('[SupabasePostRepository] commentPost error: $e');
      }
    }
  }

  @override
  Future<List<AppComment>> getComments(String postId) async {
    if (SupabaseConfig.isConfigured) {
      try {
        final client = SupabaseConfig.client!;
        final res = await client
            .from('comments')
            .select('*, profiles!inner(handle, display_name, avatar_url)')
            .eq('post_id', postId)
            .order('created_at', ascending: true);

        return (res as List).map((row) {
          final profile = row['profiles'] as Map<String, dynamic>?;
          final handle = profile?['handle'] as String? ?? 'trader';
          final name = profile?['display_name'] as String? ?? handle;

          return AppComment(
            id: row['id'] as String,
            author: AppTrader(
              id: row['user_id'] as String? ?? 'usr_trader',
              handle: handle,
              displayName: name,
              avatarUrl: profile?['avatar_url'] as String?,
            ),
            body: row['content'] as String? ?? '',
            createdAt: row['created_at'] != null
                ? DateTime.parse(row['created_at'] as String)
                : DateTime.now(),
            likes: row['likes'] as int? ?? 0,
          );
        }).toList();
      } catch (e) {
        debugPrint('[SupabasePostRepository] getComments error: $e');
      }
    }
    return _demo.comments(postId);
  }

  @override
  Future<void> savePost(String postId) async {
    if (SupabaseConfig.isConfigured) {
      try {
        final client = SupabaseConfig.client!;
        final user = client.auth.currentUser;
        if (user != null) {
          await client.from('saved_posts').upsert({
            'user_id': user.id,
            'post_id': postId,
          });
        }
      } catch (e) {
        debugPrint('[SupabasePostRepository] savePost error: $e');
      }
    }
  }

  @override
  Future<void> incrementView(String postId) async {
    if (SupabaseConfig.isConfigured) {
      try {
        final client = SupabaseConfig.client!;
        await client.rpc('increment_post_views', params: {'p_post_id': postId});
      } catch (e) {
        debugPrint('[SupabasePostRepository] incrementView error: $e');
      }
    }
  }

  @override
  Future<void> blockUser(String userIdToBlock) async {
    if (SupabaseConfig.isConfigured) {
      try {
        final client = SupabaseConfig.client!;
        final user = client.auth.currentUser;
        if (user != null) {
          await client.from('blocks').upsert({
            'blocker_id': user.id,
            'blocked_id': userIdToBlock,
          });
        }
      } catch (e) {
        debugPrint('[SupabasePostRepository] blockUser error: $e');
      }
    }
  }
}
