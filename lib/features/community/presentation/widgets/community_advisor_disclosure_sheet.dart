import 'package:flutter/material.dart';
import 'package:alphajournal/core/app-ui/app_ui.dart';
import 'package:alphajournal/core/flutter-ui/flutter_ui.dart';
import 'package:alphajournal/features/auth/models/auth_user_role.dart';
import 'package:alphajournal/features/community/models/community_models.dart';
import 'package:alphajournal/features/community/presentation/widgets/community_design.dart';

/// Modal bottom sheet displaying verified Research Analyst / RIA regulatory credentials
/// and mandatory conflict of interest disclosures.
class CommunityAdvisorDisclosureSheet extends StatelessWidget {
  const CommunityAdvisorDisclosureSheet({super.key, required this.author});

  final CommunityAuthor author;

  static Future<void> show(BuildContext context, {CommunityAuthor? author}) {
    final fallback =
        author ??
        const CommunityAuthor(
          id: 'unverified_member',
          displayName: 'Community Trader',
          handle: 'trader',
          verified: false,
          userRole: UserRole.customer,
          primaryMarket: 'Equity & Derivatives',
        );

    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => CommunityDensityScope(
        child: CommunityAdvisorDisclosureSheet(author: fallback),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.ui;
    final colors = theme.colors;

    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(context.sz(20)),
        ),
        border: Border.all(color: colors.border),
      ),
      padding: EdgeInsets.fromLTRB(
        context.sp(20),
        context.sp(12),
        context.sp(20),
        context.sp(28),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: context.sz(40),
              height: context.sz(4),
              decoration: BoxDecoration(
                color: colors.border,
                borderRadius: BorderRadius.circular(context.sz(2)),
              ),
            ),
          ),
          SizedBox(height: context.sp(16)),

          // Header
          Row(
            children: [
              UiAvatar(name: author.displayName, size: UiSize.md),
              SizedBox(width: context.sp(12)),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            author.displayName,
                            style: context.uiText.subheading.copyWith(
                              fontWeight: FontWeight.w700,
                              color: colors.foreground,
                            ),
                          ),
                        ),
                        if (author.verified) ...[
                          SizedBox(width: context.sp(4)),
                          Icon(
                            Icons.verified,
                            color: colors.primary,
                            size: context.sz(16),
                          ),
                        ],
                      ],
                    ),
                    Text(
                      author.verified
                          ? 'Verified Profile (Identity Confirmed)'
                          : 'Community Member (Unverified Advisor Status)',
                      style: context.uiText.label.copyWith(
                        color: author.verified
                            ? colors.success
                            : colors.foregroundMuted,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              UiIconButton(
                icon: Icons.close,
                size: UiSize.sm,
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          SizedBox(height: context.sp(20)),

          // Credentials Box
          Container(
            padding: EdgeInsets.all(context.sp(14)),
            decoration: BoxDecoration(
              color: colors.surfaceMuted,
              borderRadius: BorderRadius.circular(context.sz(10)),
              border: Border.all(color: colors.border),
            ),
            child: Column(
              children: [
                _InfoRow(
                  label: 'SEBI Registration',
                  value: 'Not on file / Unregistered',
                ),
                _InfoRow(
                  label: 'Regulatory Status',
                  value: 'Self-directed trader (Educational only)',
                ),
                _InfoRow(
                  label: 'Advisory Authorization',
                  value: 'None (No financial advice allowed)',
                ),
                _InfoRow(
                  label: 'Platform Identity',
                  value: author.verified ? 'Verified' : 'Standard member',
                ),
              ],
            ),
          ),
          SizedBox(height: context.sp(16)),

          Text(
            'Mandatory Disclosures & Disclaimers',
            style: context.uiText.label.copyWith(
              fontWeight: FontWeight.w700,
              color: colors.foreground,
            ),
          ),
          SizedBox(height: context.sp(8)),
          Text(
            '1. Securities investments are subject to market risks. Read all scheme and offer documents carefully.\n'
            '2. The analyst or their associates may have personal or financial interest in the securities recommended above.\n'
            '3. Past performance does not guarantee future results. AlphaJournal and the analyst do not offer guaranteed returns.\n'
            '4. Research reports are prepared for general circulation and do not account for individual investor objectives.',
            style: context.uiText.caption.copyWith(
              color: colors.foregroundMuted,
              height: 1.45,
            ),
          ),
          SizedBox(height: context.sp(20)),

          UiButton(
            label: 'Close Disclosures',
            variant: UiVariant.primary,
            size: UiSize.md,
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colors = context.ui.colors;
    return Padding(
      padding: EdgeInsets.symmetric(vertical: context.sp(4)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: context.uiText.caption.copyWith(
              color: colors.foregroundMuted,
            ),
          ),
          Text(
            value,
            style: context.uiText.caption.copyWith(
              fontWeight: FontWeight.w600,
              color: colors.foreground,
            ),
          ),
        ],
      ),
    );
  }
}
