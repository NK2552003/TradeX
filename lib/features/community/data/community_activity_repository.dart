part of 'community_repository.dart';

extension CommunityActivityRepository on CommunityRepository {
  /// Read every page so filter totals describe the actual visible reactors.
  Future<List<CommunityReaction>> _fetchReactions(
    String targetId, {
    bool comment = false,
  }) async {
    if (!SupabaseConfig.isConfigured) {
      final post = findPost(targetId);
      if (!comment && post != null && post.liked) {
        return [
          CommunityReaction(
            author: currentAuthor,
            reaction: post.userReaction ?? '👍',
          ),
        ];
      }
      return [];
    }
    final client = SupabaseConfig.client!;
    final result = <CommunityReaction>[];
    const pageSize = 200;
    for (var offset = 0; ; offset += pageSize) {
      final rows = await client
          .from(comment ? 'community_comment_likes' : 'community_likes')
          .select(
            'user_id, reaction, profiles!user_id(id, handle, display_name, avatar_url, bio, role, verified)${comment ? ', community_comments!inner(id, community_posts!inner(id))' : ''}',
          )
          .eq(comment ? 'comment_id' : 'post_id', targetId)
          .order('user_id')
          .range(offset, offset + pageSize - 1);
      for (final row in rows) {
        final profile = row['profiles'];
        final id = row['user_id']?.toString() ?? '';
        if (profile is! Map<String, dynamic> || _blockedUsers.contains(id)) {
          continue;
        }
        result.add(
          CommunityReaction(
            author: CommunityRepository.mapProfileToCommunityAuthor(
              authorId: profile['id'].toString(),
              authorProfile: profile,
              isFollowing: isFollowing(id),
            ),
            reaction: row['reaction']?.toString() ?? '👍',
          ),
        );
      }
      if (rows.length < pageSize) break;
    }
    return result;
  }

  List<CommunityReaction> followedReactionsForPost(String postId) =>
      (_networkReactions[postId] ?? const <CommunityReaction>[])
          .where(
            (r) =>
                isFollowing(r.author.id) &&
                !_blockedUsers.contains(r.author.id) &&
                !_mutedUsers.contains(r.author.id),
          )
          .toList();

  List<CommunityAuthor> followedRepostsForPost(String postId) =>
      (_networkReposts[postId] ?? const <CommunityAuthor>[])
          .where(
            (author) =>
                isFollowing(author.id) &&
                !_blockedUsers.contains(author.id) &&
                !_mutedUsers.contains(author.id),
          )
          .toList();

  Future<void> _fetchNetworkActivity(List<CommunityPost> posts) async {
    final request = ++_networkRequest;
    final visibleIds = posts
        .where((p) => p.isPublic && p.moderationStatus == 'approved')
        .map((p) => p.id)
        .toList();
    if (_followedAuthorIds.isEmpty || visibleIds.isEmpty) {
      _networkReactions.clear();
      _networkReposts.clear();
      return;
    }
    final followedIds = _followedAuthorIds.toList();
    // A failure in either activity source must not discard the other source.
    for (final table in ['community_likes', 'community_reposts']) {
      final reactions = <String, List<CommunityReaction>>{};
      final reposts = <String, List<CommunityAuthor>>{};
      final isRepost = table == 'community_reposts';
      try {
        final client = SupabaseConfig.client!;
        for (var start = 0; start < visibleIds.length; start += 100) {
          final ids = visibleIds.skip(start).take(100).toList();
          for (var offset = 0; ; offset += 200) {
            final rows = await client
                .from(table)
                .select(
                  'post_id, user_id, ${isRepost ? '' : 'reaction, '}profiles!user_id(id, handle, display_name, avatar_url, bio, role, verified)',
                )
                .inFilter('post_id', ids)
                .inFilter('user_id', followedIds)
                .order('created_at', ascending: false)
                .order('post_id')
                .order('user_id')
                .range(offset, offset + 199);
            for (final row in rows) {
              final profile = row['profiles'];
              if (profile is! Map<String, dynamic>) continue;
              final author = CommunityRepository.mapProfileToCommunityAuthor(
                authorId: profile['id'].toString(),
                authorProfile: profile,
                isFollowing: true,
              );
              final postId = row['post_id'].toString();
              if (isRepost) {
                (reposts[postId] ??= []).add(author);
              } else {
                (reactions[postId] ??= []).add(
                  CommunityReaction(
                    author: author,
                    reaction: row['reaction']?.toString() ?? '👍',
                  ),
                );
              }
            }
            if (rows.length < 200) break;
          }
        }
        if (!_disposed && request == _networkRequest) {
          if (isRepost) {
            _networkReposts
              ..clear()
              ..addAll(reposts);
          } else {
            _networkReactions
              ..clear()
              ..addAll(reactions);
          }
        }
      } catch (error) {
        debugPrint('[CommunityRepository] $table activity unavailable: $error');
      }
    }
  }
}
