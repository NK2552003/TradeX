import 'package:flutter/material.dart';
import 'package:tradex/core/app-ui/app_ui.dart';
import 'package:tradex/core/flutter-ui/flutter_ui.dart';
import 'package:tradex/features/community/presentation/widgets/community_design.dart';

/// Modal dialog displaying platform community guidelines, ethical trading conduct,
/// and regulatory compliance notices.
class CommunityGuidelinesDialog extends StatelessWidget {
  const CommunityGuidelinesDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog<void>(
      context: context,
      builder: (ctx) =>
          const CommunityDensityScope(child: CommunityGuidelinesDialog()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.ui;
    final colors = theme.colors;

    final rules = [
      (
        icon: Icons.verified_user_outlined,
        title: 'No Front-Running or Pump & Dump',
        body:
            'Do not coordinate artificial price surges, market manipulation, or misleading trade setups. Personal holdings must be disclosed when sharing trading ideas.',
      ),
      (
        icon: Icons.gavel_outlined,
        title: 'Educational Content Only',
        body:
            'Shared setups, charts, and strategies are for research and educational purposes only. They do not constitute certified investment advice.',
      ),
      (
        icon: Icons.shield_outlined,
        title: 'Zero Tolerance for Financial Scams',
        body:
            'Promoting guaranteed returns, unregistered fund management, paid illicit telegram tips, or phishing links results in immediate, permanent account termination.',
      ),
      (
        icon: Icons.handshake_outlined,
        title: 'Civil & Constructive Debate',
        body:
            'Disagreements on technical setups or market perspectives are welcomed. Personal abuse, harassment, or defamatory speech will not be tolerated.',
      ),
      (
        icon: Icons.account_balance_outlined,
        title: 'SEBI / Regulatory Compliance',
        body:
            'Traders claiming Research Analyst (RA) or Investment Adviser (RIA) status must display verified credentials and state their registration numbers prominently.',
      ),
    ];

    return Dialog(
      backgroundColor: colors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(context.sz(16)),
        side: BorderSide(color: colors.border),
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: context.sz(520), maxHeight: 600),
        child: Padding(
          padding: EdgeInsets.all(context.sp(20)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(context.sp(8)),
                    decoration: BoxDecoration(
                      color: colors.primary.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.policy_outlined,
                      color: colors.primary,
                      size: context.sz(20),
                    ),
                  ),
                  SizedBox(width: context.sp(12)),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Community Code of Conduct',
                          style: context.uiText.heading.copyWith(
                            fontWeight: FontWeight.w700,
                            color: colors.foreground,
                          ),
                        ),
                        Text(
                          'Standards for fair, transparent & educational trading',
                          style: context.uiText.caption.copyWith(
                            color: colors.foregroundMuted,
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
              SizedBox(height: context.sp(16)),
              const UiDivider(),
              SizedBox(height: context.sp(12)),
              Expanded(
                child: ListView.separated(
                  itemCount: rules.length,
                  separatorBuilder: (_, _) => SizedBox(height: context.sp(16)),
                  itemBuilder: (ctx, idx) {
                    final item = rules[idx];
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: EdgeInsets.all(context.sp(8)),
                          decoration: BoxDecoration(
                            color: colors.surfaceMuted,
                            borderRadius: BorderRadius.circular(context.sz(8)),
                          ),
                          child: Icon(
                            item.icon,
                            size: context.sz(18),
                            color: colors.primary,
                          ),
                        ),
                        SizedBox(width: context.sp(12)),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.title,
                                style: context.uiText.body.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: colors.foreground,
                                ),
                              ),
                              SizedBox(height: context.sp(4)),
                              Text(
                                item.body,
                                style: context.uiText.caption.copyWith(
                                  color: colors.foregroundMuted,
                                  height: 1.35,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
              SizedBox(height: context.sp(16)),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  UiButton(
                    label: 'I Understand & Agree',
                    variant: UiVariant.primary,
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
