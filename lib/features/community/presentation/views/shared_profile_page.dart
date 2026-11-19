import 'package:flutter/material.dart';
import 'package:alphajournal/core/app-ui/app_ui.dart';
// ignore: unnecessary_import
import 'package:alphajournal/core/flutter-ui/flutter_ui.dart';
import 'package:alphajournal/core/config/supabase_config.dart';
import 'package:alphajournal/features/community/data/community_repository.dart';
import 'package:alphajournal/features/community/models/community_models.dart';
import 'package:alphajournal/features/settings/presentation/pages/shared/trader_profile_preview_page.dart';

/// Resolves the handle from a shared URL before opening the existing profile.
/// Supplying the actual author ID keeps all record tabs scoped to that trader.
class SharedProfilePage extends StatefulWidget {
  const SharedProfilePage({
    super.key,
    required this.handle,
    required this.repository,
    this.onOpenRef,
  });

  final String handle;
  final CommunityRepository repository;
  final ValueChanged<AppLinkRef>? onOpenRef;

  @override
  State<SharedProfilePage> createState() => _SharedProfilePageState();
}

class _SharedProfilePageState extends State<SharedProfilePage> {
  late Future<CommunityAuthor?> _author = _load();

  Future<CommunityAuthor?> _load() async {
    final client = SupabaseConfig.client;
    if (client == null) {
      return widget.repository.suggestedTraders
          .where(
            (author) =>
                author.cleanHandle.toLowerCase() == widget.handle.toLowerCase(),
          )
          .firstOrNull;
    }
    final rows = await client
        .from('profiles')
        .select(
          'id,handle,display_name,avatar_url,bio,role,verified,'
          'subscription_tier,experience_level,trading_style,location,website,'
          'avg_hold_duration,primary_market,top_strategy,risk_mantra,'
          'followers_count,following_count,win_rate,public_stats,posts_count',
        )
        .or('handle.eq.${widget.handle},handle.eq.@${widget.handle}')
        .limit(1);
    if (rows.isEmpty) return null;
    final row = rows.first;
    return CommunityRepository.mapProfileToCommunityAuthor(
      authorId: row['id'] as String,
      authorProfile: Map<String, dynamic>.from(row),
    );
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<CommunityAuthor?>(
    future: _author,
    builder: (context, snapshot) {
      if (snapshot.connectionState != ConnectionState.done) {
        return Scaffold(
          backgroundColor: context.uiColors.background,
          body: AlphaThreadBackdrop.auth(
            showSideEdges: context.uiRes.isDesktop,
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 700),
                child: UiSkeleton.profilePreview(),
              ),
            ),
          ),
        );
      }
      if (snapshot.hasError) {
        return UiEmptyState(
          icon: Icons.cloud_off_outlined,
          title: 'Profile could not be loaded',
          message: 'Check your connection and try again.',
          action: UiButton(
            label: 'Try again',
            onPressed: () => setState(() => _author = _load()),
          ),
        );
      }
      final author = snapshot.data;
      if (author == null) {
        return UiEmptyState(
          icon: Icons.person_off_outlined,
          title: 'Profile not found',
          message: '@${widget.handle} is unavailable.',
        );
      }
      return TraderProfilePreviewPage(
        displayName: author.displayName,
        handle: author.handle,
        userRole: author.userRole,
        author: author,
        repository: widget.repository,
        forceTraderView: true,
        isCurrentUser: author.id == SupabaseConfig.client?.auth.currentUser?.id,
        onOpenRef: widget.onOpenRef,
      );
    },
  );
}
