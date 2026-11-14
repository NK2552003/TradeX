import 'community_models.dart';

class CommunityReaction {
  const CommunityReaction({required this.author, required this.reaction});
  final CommunityAuthor author;
  final String reaction;

  String get activityLabel =>
      reaction == '👍' ? 'likes this' : 'reacted $reaction to this';
}

/// Accepts both flat database rows and already nested optimistic replies.
List<CommunityComment> buildCommunityCommentTree(
  List<CommunityComment> comments,
) {
  final byId = <String, CommunityComment>{};
  void collect(CommunityComment comment) {
    byId[comment.id] = comment;
    for (final reply in comment.replies) {
      collect(reply);
    }
  }

  for (final comment in comments) {
    collect(comment);
  }
  final children = <String, List<String>>{};
  for (final comment in byId.values) {
    final parent = comment.parentCommentId;
    if (parent != null && parent != comment.id && byId.containsKey(parent)) {
      (children[parent] ??= []).add(comment.id);
    }
    for (final reply in comment.replies) {
      final ids = children[comment.id] ??= [];
      if (!ids.contains(reply.id)) ids.add(reply.id);
    }
  }
  final visited = <String>{};
  CommunityComment? build(String id) {
    if (!visited.add(id)) return null;
    return byId[id]!.copyWith(
      replies: [for (final child in children[id] ?? <String>[]) ?build(child)],
    );
  }

  final nested = children.values.expand((ids) => ids).toSet();
  final roots = <CommunityComment>[];
  for (final id in [
    ...byId.keys.where((id) => !nested.contains(id)),
    ...byId.keys,
  ]) {
    if (build(id) case final root?) roots.add(root);
  }
  return roots;
}
