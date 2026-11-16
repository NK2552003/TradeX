import 'package:flutter/material.dart';
import 'package:tradex/core/app-ui/app_ui.dart';
import 'package:tradex/core/flutter-ui/flutter_ui.dart';
import 'package:tradex/core/markdown_kit/markdown_preview.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../data/admin_repository.dart';
import '../../models/admin_records.dart';
import 'admin_facts.dart';
import 'admin_record_actions.dart';

UiIntent adminStatusIntent(String status) => switch (status.toLowerCase()) {
  'active' ||
  'approved' ||
  'paid' ||
  'complete' ||
  'completed' ||
  'public' ||
  'live' ||
  'converted' => UiIntent.success,
  'pending' ||
  'pending_approval' ||
  'pending_review' ||
  'processing' ||
  'grace_period' ||
  'reserved' ||
  'recorded' => UiIntent.warning,
  'suspended' ||
  'rejected' ||
  'restricted' ||
  'failed' ||
  'canceled' ||
  'cancelled' ||
  'past_due' ||
  'expired' ||
  'churned' => UiIntent.danger,
  _ => UiIntent.neutral,
};

IconData adminResourceIcon(AdminResource resource) => switch (resource) {
  AdminResource.users => Icons.person_outline_rounded,
  AdminResource.applications => Icons.assignment_ind_outlined,
  AdminResource.affiliates => Icons.handshake_outlined,
  AdminResource.posts => Icons.forum_outlined,
  AdminResource.comments => Icons.chat_bubble_outline_rounded,
  AdminResource.subscriptions => Icons.credit_card_outlined,
  AdminResource.notes => Icons.description_outlined,
  AdminResource.journal => Icons.candlestick_chart_outlined,
  AdminResource.strategies => Icons.psychology_outlined,
  AdminResource.messages => Icons.mail_outline_rounded,
  AdminResource.ai => Icons.auto_awesome_outlined,
  AdminResource.aiRequests => Icons.bolt_outlined,
  AdminResource.aiMessages => Icons.smart_toy_outlined,
  AdminResource.activity => Icons.history_rounded,
  AdminResource.referrals => Icons.group_add_outlined,
  AdminResource.payouts => Icons.payments_outlined,
  AdminResource.deletions => Icons.delete_sweep_outlined,
};

String _sanitizeText(Object? raw) {
  if (raw == null) return '';
  if (raw is Map) {
    final candidate =
        raw['markdown']?.toString() ??
        raw['text']?.toString() ??
        raw['body']?.toString() ??
        raw.toString();
    return _sanitizeText(candidate);
  }
  final text = raw.toString().trim();
  if (text.isEmpty) return '';
  if (text.startsWith('e2ee:v1:')) {
    return 'End-to-end encrypted content';
  }
  return text.replaceAll(RegExp(r'\s+'), ' ');
}

String adminPreviewExcerpt(AdminRecord row, AdminResource resource) {
  final directPreview = _sanitizeText(row.values['preview']);
  if (directPreview.isNotEmpty) return directPreview;

  switch (resource) {
    case AdminResource.posts:
    case AdminResource.comments:
    case AdminResource.messages:
    case AdminResource.aiMessages:
      final body = _sanitizeText(row.values['body'] ?? row.values['content']);
      if (body.isNotEmpty) return body;
    case AdminResource.notes:
    case AdminResource.journal:
    case AdminResource.strategies:
      final snippet = _sanitizeText(
        row.values['summary'] ??
            row.values['ai_summary'] ??
            row.values['content'] ??
            row.values['body'],
      );
      if (snippet.isNotEmpty) return snippet;
      final ticker = row.text('ticker');
      final side = row.text('side');
      if (ticker.isNotEmpty || side.isNotEmpty) {
        return [
          if (ticker.isNotEmpty) ticker,
          if (side.isNotEmpty) side.toUpperCase(),
          if (row.count('word_count') > 0) '${row.count('word_count')} words',
        ].join(' · ');
      }
    case AdminResource.aiRequests:
      final prompt = _sanitizeText(
        row.values['prompt_text'] ?? row.values['summary'],
      );
      if (prompt.isNotEmpty) return prompt;
      final model = row.text('model', row.text('provider'));
      if (model.isNotEmpty) return 'Model: $model';
    case AdminResource.applications:
      final parts = [
        if (row.text('primary_platform').isNotEmpty)
          row.text('primary_platform'),
        if (row.text('audience_reach').isNotEmpty) row.text('audience_reach'),
        if (row.text('channel_handle').isNotEmpty) row.text('channel_handle'),
      ];
      if (parts.isNotEmpty) return parts.join(' · ');
    case AdminResource.deletions:
      final reason = _sanitizeText(row.values['reason']);
      if (reason.isNotEmpty) return reason;
    case AdminResource.activity:
      final metaReason = _sanitizeText(adminMap(row.values['metadata'])['reason']);
      if (metaReason.isNotEmpty) return metaReason;
    case AdminResource.users:
    case AdminResource.subscriptions:
    case AdminResource.affiliates:
      final email = row.text('email');
      final handle = row.text('handle');
      if (handle.isNotEmpty && email.isNotEmpty) return '@$handle · $email';
      if (email.isNotEmpty) return email;
      if (handle.isNotEmpty) return '@$handle';
    case AdminResource.payouts:
      final method = row.text('payout_method');
      final amount = row.text('amount');
      final currency = row.text('currency', 'INR');
      return [
        if (amount.isNotEmpty) '$amount $currency',
        if (method.isNotEmpty) adminLabel(method),
      ].join(' · ');
    case AdminResource.referrals:
      final code = row.text('referral_code');
      final tier = row.text('subscription_tier');
      return [
        if (code.isNotEmpty) 'Code $code',
        if (tier.isNotEmpty) adminLabel(tier),
      ].join(' · ');
    case AdminResource.ai:
      final persona = row.text('persona');
      final msgCount = row.count('messages_count');
      return [
        if (persona.isNotEmpty) adminLabel(persona),
        '$msgCount messages',
      ].join(' · ');
  }
  return '';
}

List<String> _extractStringList(Object? value) {
  if (value is List) {
    return value
        .map((e) => e?.toString().trim() ?? '')
        .where((e) => e.isNotEmpty)
        .toList();
  }
  return const <String>[];
}

/// Rich visual preview card for a single record in any admin collection or overview feed.
class AdminVisualRecordCard extends StatelessWidget {
  const AdminVisualRecordCard({
    super.key,
    required this.resource,
    required this.record,
    required this.onOpenDetails,
    this.onPreview,
    this.selected = false,
  });

  final AdminResource resource;
  final AdminRecord record;
  final VoidCallback onOpenDetails;
  final VoidCallback? onPreview;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final theme = context.ui;
    final colors = theme.colors;
    final status = record.status;
    final intent = adminStatusIntent(status);
    final excerpt = adminPreviewExcerpt(record, resource);
    final author = record.text('author', record.text('actor_handle'));
    final email = record.text('email');
    final avatarUrl = record.values['avatar_url']?.toString() ??
        record.values['author_avatar_url']?.toString();
    final tickers = _extractStringList(record.values['tickers']);
    final tickerSingle = record.text('ticker');
    final allTickers = <String>[
      if (tickerSingle.isNotEmpty) tickerSingle,
      ...tickers.where((t) => t != tickerSingle),
    ].take(3).toList();

    final bool showAvatar =
        author.isNotEmpty ||
        resource == AdminResource.users ||
        resource == AdminResource.affiliates ||
        resource == AdminResource.subscriptions ||
        resource == AdminResource.applications;

    final Color accentColor = selected
        ? colors.primary
        : switch (intent) {
            UiIntent.danger => colors.bearish,
            UiIntent.warning => colors.warning,
            UiIntent.success => colors.success,
            _ => colors.borderStrong,
          };

    return UiCard(
      variant: selected ? UiCardVariant.elevated : UiCardVariant.surface,
      accentColor: accentColor,
      onTap: onPreview ?? onOpenDetails,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (showAvatar) ...[
                UiAvatar(
                  name: author.isNotEmpty ? author : record.title,
                  imageUrl: avatarUrl?.isNotEmpty == true ? avatarUrl : null,
                  size: UiSize.sm,
                ),
                SizedBox(width: context.sp(theme.spacing.sm)),
              ] else ...[
                Icon(
                  adminResourceIcon(resource),
                  size: context.sz(theme.sizes.iconMd),
                  color: colors.primary,
                ),
                SizedBox(width: context.sp(theme.spacing.sm)),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      record.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: context.uiText.bodyStrong,
                    ),
                    if (author.isNotEmpty && author != record.title)
                      Text(
                        author,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.uiText.caption.copyWith(
                          color: colors.foregroundMuted,
                        ),
                      )
                    else if (email.isNotEmpty)
                      Text(
                        email,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.uiText.caption.copyWith(
                          color: colors.foregroundMuted,
                        ),
                      ),
                  ],
                ),
              ),
              SizedBox(width: context.sp(theme.spacing.xs)),
              UiBadge(
                label: adminLabel(status),
                intent: intent,
                size: UiSize.xs,
              ),
            ],
          ),
          if (excerpt.isNotEmpty) ...[
            SizedBox(height: context.sp(theme.spacing.sm)),
            Text(
              excerpt,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: context.uiText.body.copyWith(
                color: colors.foregroundMuted,
              ),
            ),
          ],
          SizedBox(height: context.sp(theme.spacing.sm)),
          Wrap(
            spacing: context.sp(theme.spacing.xs),
            runSpacing: context.sp(theme.spacing.xs),
            children: [
              ..._buildDomainBadges(context),
              for (final ticker in allTickers)
                UiBadge(
                  label: ticker,
                  variant: UiBadgeVariant.outline,
                  size: UiSize.xs,
                ),
            ],
          ),
          SizedBox(height: context.sp(theme.spacing.sm)),
          const UiDivider(),
          SizedBox(height: context.sp(theme.spacing.xs)),
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: context.sp(theme.spacing.xs),
            runSpacing: context.sp(theme.spacing.xs),
            children: [
              Text(
                adminDate(record.values['created_at']),
                style: context.uiText.caption.copyWith(
                  color: colors.foregroundSubtle,
                ),
              ),
              Wrap(
                spacing: context.sp(theme.spacing.xs),
                children: [
                  if (onPreview != null)
                    UiButton(
                      label: 'Preview',
                      leadingIcon: Icons.visibility_outlined,
                      size: UiSize.xs,
                      variant: selected ? UiVariant.soft : UiVariant.ghost,
                      onPressed: onPreview,
                    ),
                  UiButton(
                    label: 'Details',
                    leadingIcon: Icons.open_in_new_rounded,
                    size: UiSize.xs,
                    variant: UiVariant.outline,
                    onPressed: onOpenDetails,
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  List<Widget> _buildDomainBadges(BuildContext context) {
    return switch (resource) {
      AdminResource.users => [
        if (record.text('tier').isNotEmpty)
          UiBadge(
            label: adminLabel(record.text('tier')),
            intent: UiIntent.primary,
            size: UiSize.xs,
          ),
        if (record.text('role').isNotEmpty)
          UiBadge(label: adminLabel(record.text('role')), size: UiSize.xs),
        if (record.count('posts_count') > 0)
          UiBadge(
            label: '${record.count('posts_count')} posts',
            size: UiSize.xs,
          ),
      ],
      AdminResource.subscriptions => [
        if (record.text('tier').isNotEmpty)
          UiBadge(
            label: 'Effective: ${adminLabel(record.text('tier'))}',
            intent: UiIntent.primary,
            size: UiSize.xs,
          ),
        if (record.text('billing_provider').isNotEmpty)
          UiBadge(
            label: adminLabel(record.text('billing_provider')),
            size: UiSize.xs,
          ),
      ],
      AdminResource.posts => [
        UiBadge(
          label: '${record.count('views_count')} views',
          size: UiSize.xs,
        ),
        UiBadge(
          label: '${record.count('likes_count')} likes',
          size: UiSize.xs,
        ),
        UiBadge(
          label: '${record.count('comments_count')} comments',
          size: UiSize.xs,
        ),
        if (record.flag('is_pinned'))
          const UiBadge(
            label: 'Pinned',
            intent: UiIntent.primary,
            size: UiSize.xs,
          ),
        if (record.flag('is_featured'))
          const UiBadge(
            label: 'Featured',
            intent: UiIntent.info,
            size: UiSize.xs,
          ),
      ],
      AdminResource.journal => [
        if (record.text('side').isNotEmpty)
          UiBadge(
            label: record.text('side').toUpperCase(),
            intent: record.text('side').toLowerCase() == 'long'
                ? UiIntent.bullish
                : UiIntent.bearish,
            size: UiSize.xs,
          ),
        if (record.values['pnl'] is num)
          UiBadge(
            label:
                'P&L ${(record.values['pnl'] as num) >= 0 ? '+' : ''}${(record.values['pnl'] as num).toStringAsFixed(2)}',
            intent: (record.values['pnl'] as num) >= 0
                ? UiIntent.bullish
                : UiIntent.bearish,
            size: UiSize.xs,
          ),
        if (record.count('word_count') > 0)
          UiBadge(label: '${record.count('word_count')} words', size: UiSize.xs),
      ],
      AdminResource.notes || AdminResource.strategies => [
        if (record.count('word_count') > 0)
          UiBadge(label: '${record.count('word_count')} words', size: UiSize.xs),
        if (record.flag('is_public') || record.text('visibility') == 'public')
          const UiBadge(
            label: 'Public',
            intent: UiIntent.info,
            size: UiSize.xs,
          ),
      ],
      AdminResource.affiliates => [
        UiBadge(
          label:
              '${((record.values['commission_rate'] as num? ?? 0) * 100).toStringAsFixed(1)}% rate',
          intent: UiIntent.primary,
          size: UiSize.xs,
        ),
        if (record.text('tier').isNotEmpty)
          UiBadge(label: adminLabel(record.text('tier')), size: UiSize.xs),
      ],
      AdminResource.payouts => [
        UiBadge(
          label: '${record.text('amount', '0')} ${record.text('currency', 'INR')}',
          intent: UiIntent.primary,
          size: UiSize.xs,
        ),
        if (record.text('payout_method').isNotEmpty)
          UiBadge(
            label: adminLabel(record.text('payout_method')),
            size: UiSize.xs,
          ),
      ],
      AdminResource.aiRequests => [
        if (record.text('provider').isNotEmpty)
          UiBadge(
            label: adminLabel(record.text('provider')),
            intent: UiIntent.primary,
            size: UiSize.xs,
          ),
        if (record.count('input_tokens') + record.count('output_tokens') > 0)
          UiBadge(
            label:
                '${record.count('input_tokens') + record.count('output_tokens')} tok',
            size: UiSize.xs,
          ),
      ],
      AdminResource.deletions => [
        if (record.text('data_purge_condition').isNotEmpty)
          UiBadge(
            label: adminLabel(record.text('data_purge_condition')),
            intent: UiIntent.warning,
            size: UiSize.xs,
          ),
      ],
      _ => [
        if (record.flag('admin_hidden'))
          const UiBadge(
            label: 'Restricted',
            intent: UiIntent.danger,
            size: UiSize.xs,
          ),
      ],
    };
  }
}

/// Full visual user-view preview for any single record, rendered inside both
/// the live inspector drawer/split-pane and [AdminRecordDetailPage].
class AdminRecordPreviewContent extends StatelessWidget {
  const AdminRecordPreviewContent({
    super.key,
    required this.resource,
    required this.record,
    this.compact = false,
    this.showEngagementMetrics = true,
  });

  final AdminResource resource;
  final AdminRecord record;
  final bool compact;
  final bool showEngagementMetrics;

  String _extractMarkdownBody(Object? value) {
    if (value == null) return '';
    if (value is Map) {
      return value['markdown']?.toString() ??
          value['text']?.toString() ??
          value['body']?.toString() ??
          value.toString();
    }
    return value.toString();
  }

  Future<void> _openUrl(BuildContext context, String rawUrl) async {
    final uri = Uri.tryParse(rawUrl.trim());
    if (uri == null || !['https', 'http'].contains(uri.scheme)) {
      UiToast.error(context, title: 'Invalid sample link');
      return;
    }
    try {
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication) &&
          context.mounted) {
        UiToast.error(context, title: 'Unable to open sample');
      }
    } catch (_) {
      if (context.mounted) {
        UiToast.error(context, title: 'Unable to open sample');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.ui;
    final colors = theme.colors;
    final bodyRaw = record.values['body'] ?? record.values['content'];
    final bodyText = _extractMarkdownBody(bodyRaw);
    final isEncrypted = bodyText.trim().startsWith('e2ee:v1:');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (resource == AdminResource.posts ||
            resource == AdminResource.comments) ...[
          UiCard(
            variant: UiCardVariant.surface,
            title: record.title,
            subtitle:
                '${record.text('author', 'Trader')} · ${adminDate(record.values['created_at'])}',
            leading: UiAvatar(
              name: record.text('author', 'Trader'),
              imageUrl: record.values['author_avatar_url']?.toString(),
              size: UiSize.sm,
            ),
            trailing: UiBadge(
              label: adminLabel(record.status),
              intent: adminStatusIntent(record.status),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (bodyText.trim().isNotEmpty)
                  RichMarkdownPreview(data: bodyText)
                else
                  Text(
                    'No body text recorded.',
                    style: context.uiText.caption.copyWith(
                      color: colors.foregroundMuted,
                    ),
                  ),
                if (resource == AdminResource.posts &&
                    showEngagementMetrics) ...[
                  SizedBox(height: context.sp(theme.spacing.md)),
                  UiStatStrip(
                    density: UiDensity.compact,
                    stats: [
                      UiStat(
                        label: 'Views',
                        value: '${record.count('views_count')}',
                      ),
                      UiStat(
                        label: 'Likes',
                        value: '${record.count('likes_count')}',
                      ),
                      UiStat(
                        label: 'Comments',
                        value: '${record.count('comments_count')}',
                      ),
                      UiStat(
                        label: 'Reposts',
                        value: '${record.count('reposts_count')}',
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ] else if (resource == AdminResource.journal) ...[
          UiCard(
            variant: UiCardVariant.surface,
            title: record.title,
            subtitle:
                '${record.text('author', 'Trader')} · ${adminDate(record.values['created_at'])}',
            trailing: UiBadge(
              label: adminLabel(record.status),
              intent: adminStatusIntent(record.status),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                UiStatStrip(
                  density: UiDensity.compact,
                  stats: [
                    if (record.text('ticker').isNotEmpty)
                      UiStat(label: 'Ticker', value: record.text('ticker')),
                    if (record.text('side').isNotEmpty)
                      UiStat(
                        label: 'Side',
                        value: record.text('side').toUpperCase(),
                        intent: record.text('side').toLowerCase() == 'long'
                            ? UiIntent.bullish
                            : UiIntent.bearish,
                      ),
                    if (record.values['entry_price'] != null)
                      UiStat(
                        label: 'Entry',
                        value: adminValue(record.values['entry_price']),
                      ),
                    if (record.values['exit_price'] != null)
                      UiStat(
                        label: 'Exit',
                        value: adminValue(record.values['exit_price']),
                      ),
                    if (record.values['pnl'] != null)
                      UiStat(
                        label: 'P&L',
                        value: adminValue(record.values['pnl']),
                        intent: (record.values['pnl'] as num? ?? 0) >= 0
                            ? UiIntent.bullish
                            : UiIntent.bearish,
                      ),
                    if (record.values['r_multiple'] != null)
                      UiStat(
                        label: 'R-Multiple',
                        value: '${record.values['r_multiple']}R',
                      ),
                  ],
                ),
                if (bodyText.trim().isNotEmpty) ...[
                  SizedBox(height: context.sp(theme.spacing.md)),
                  RichMarkdownPreview(data: bodyText),
                ],
                if (record.text('lessons_learned').isNotEmpty) ...[
                  SizedBox(height: context.sp(theme.spacing.sm)),
                  UiCallout(
                    title: 'Lessons Learned',
                    message: record.text('lessons_learned'),
                    intent: UiIntent.info,
                  ),
                ],
              ],
            ),
          ),
        ] else if (resource == AdminResource.notes ||
            resource == AdminResource.strategies) ...[
          UiCard(
            variant: UiCardVariant.surface,
            title: record.title,
            subtitle:
                '${record.text('author', 'Trader')} · ${record.count('word_count')} words',
            trailing: UiBadge(
              label: adminLabel(record.status),
              intent: adminStatusIntent(record.status),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (record.text('ai_summary').isNotEmpty) ...[
                  UiCallout(
                    title: 'AI Summary',
                    message: record.text('ai_summary'),
                    intent: UiIntent.primary,
                  ),
                  SizedBox(height: context.sp(theme.spacing.sm)),
                ],
                if (bodyText.trim().isNotEmpty && !isEncrypted)
                  RichMarkdownPreview(data: bodyText)
                else if (isEncrypted)
                  const UiCallout(
                    title: 'Encrypted Content',
                    message: 'Protected by user end-to-end encryption.',
                    intent: UiIntent.neutral,
                  )
                else
                  Text(
                    adminPreviewExcerpt(record, resource),
                    style: context.uiText.body,
                  ),
              ],
            ),
          ),
        ] else if (resource == AdminResource.aiRequests) ...[
          UiCard(
            variant: UiCardVariant.surface,
            title: 'AI Execution Preview',
            subtitle: [
              if (record.text('provider').isNotEmpty)
                adminLabel(record.text('provider')),
              if (record.text('model').isNotEmpty) record.text('model'),
              adminDate(
                record.values['requested_at'] ?? record.values['created_at'],
              ),
            ].join(' · '),
            trailing: UiBadge(
              label: adminLabel(record.status),
              intent: adminStatusIntent(record.status),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (record.count('input_tokens') +
                        record.count('output_tokens') >
                    0) ...[
                  UiCategoryBar(
                    categories: [
                      UiCategoryItem(
                        label: 'Input (${record.count('input_tokens')} tok)',
                        value: record.count('input_tokens').toDouble(),
                        color: colors.primary,
                      ),
                      UiCategoryItem(
                        label: 'Output (${record.count('output_tokens')} tok)',
                        value: record.count('output_tokens').toDouble(),
                        color: colors.success,
                      ),
                    ],
                  ),
                  SizedBox(height: context.sp(theme.spacing.md)),
                ],
                if (record.text('prompt_text').isNotEmpty)
                  UiCallout(
                    title: 'Prompt',
                    message: record.text('prompt_text'),
                    intent: UiIntent.neutral,
                  ),
                if (record.text('response_text').isNotEmpty) ...[
                  SizedBox(height: context.sp(theme.spacing.sm)),
                  UiCard(
                    variant: UiCardVariant.outlined,
                    title: 'Assistant Response',
                    child: RichMarkdownPreview(
                      data: record.text('response_text'),
                    ),
                  ),
                ],
                if (record.text('error').isNotEmpty) ...[
                  SizedBox(height: context.sp(theme.spacing.sm)),
                  UiCallout(
                    title: 'Execution Error',
                    message: record.text('error'),
                    intent: UiIntent.danger,
                  ),
                ],
              ],
            ),
          ),
        ] else if (resource == AdminResource.applications) ...[
          UiCard(
            variant: UiCardVariant.surface,
            title: record.title,
            subtitle:
                '${record.text('email')} · ${record.text('city')}, ${record.text('state')}',
            leading: UiAvatar(name: record.title, size: UiSize.sm),
            trailing: UiBadge(
              label: adminLabel(record.status),
              intent: adminStatusIntent(record.status),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                UiStatStrip(
                  density: UiDensity.compact,
                  stats: [
                    UiStat(
                      label: 'Platform',
                      value: record.text('primary_platform', 'Not set'),
                    ),
                    UiStat(
                      label: 'Handle',
                      value: record.text('channel_handle', '—'),
                    ),
                    UiStat(
                      label: 'Audience Reach',
                      value: record.text('audience_reach', '—'),
                    ),
                    if (record.text('account_last4').isNotEmpty)
                      UiStat(
                        label: 'Account Last 4',
                        value: '•••• ${record.text('account_last4')}',
                      ),
                  ],
                ),
                if (record.text('sample_link').isNotEmpty) ...[
                  SizedBox(height: context.sp(theme.spacing.md)),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: UiButton(
                      label: 'Open application sample',
                      leadingIcon: Icons.open_in_new_rounded,
                      variant: UiVariant.outline,
                      size: UiSize.sm,
                      onPressed: () =>
                          _openUrl(context, record.text('sample_link')),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ] else if (resource == AdminResource.deletions) ...[
          UiCard(
            variant: UiCardVariant.surface,
            title: '@${record.text('user_handle', record.title)}',
            subtitle:
                'Purge schedule: ${adminDate(record.values['scheduled_purge_at'])}',
            trailing: UiBadge(
              label: adminLabel(record.status),
              intent: adminStatusIntent(record.status),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (record.text('reason').isNotEmpty)
                  UiCallout(
                    title: 'Deletion Reason',
                    message: record.text('reason'),
                    intent: UiIntent.warning,
                  ),
                SizedBox(height: context.sp(theme.spacing.sm)),
                Wrap(
                  spacing: context.sp(theme.spacing.xs),
                  runSpacing: context.sp(theme.spacing.xs),
                  children: [
                    UiBadge(
                      label: adminLabel(
                        record.text('data_purge_condition', 'immediate_purge'),
                      ),
                      intent: UiIntent.primary,
                      size: UiSize.xs,
                    ),
                    if (record.flag('purge_journals_notes_strategies'))
                      const UiBadge(
                        label: 'Purge Journals/Notes/Strategies',
                        intent: UiIntent.danger,
                        size: UiSize.xs,
                      ),
                    if (record.flag('purge_community_messages'))
                      const UiBadge(
                        label: 'Purge Community/Messages',
                        intent: UiIntent.danger,
                        size: UiSize.xs,
                      ),
                    if (record.flag('purge_ai_workspace'))
                      const UiBadge(
                        label: 'Purge AI Workspace',
                        intent: UiIntent.danger,
                        size: UiSize.xs,
                      ),
                    if (record.flag('export_requested_before_delete'))
                      const UiBadge(
                        label: 'Export Requested',
                        intent: UiIntent.info,
                        size: UiSize.xs,
                      ),
                  ],
                ),
                if (record.text('last_error').isNotEmpty) ...[
                  SizedBox(height: context.sp(theme.spacing.sm)),
                  UiCallout(
                    title: 'Previous Execution Failure',
                    message: record.text('last_error'),
                    intent: UiIntent.danger,
                  ),
                ],
              ],
            ),
          ),
        ] else ...[
          UiCard(
            variant: UiCardVariant.surface,
            title: record.title,
            subtitle: adminDate(record.values['created_at']),
            trailing: UiBadge(
              label: adminLabel(record.status),
              intent: adminStatusIntent(record.status),
            ),
            child: bodyText.trim().isNotEmpty
                ? (isEncrypted
                      ? const UiCallout(
                          title: 'Encrypted Content',
                          message:
                              'Message payload is protected by user end-to-end encryption.',
                          intent: UiIntent.neutral,
                        )
                      : SelectableText(bodyText, style: context.uiText.body))
                : Text(
                    adminPreviewExcerpt(record, resource),
                    style: context.uiText.body,
                  ),
          ),
        ],
      ],
    );
  }
}

/// Interactive split-pane / drawer inspector that fetches full live details
/// and renders a live preview + quick moderation controls for any selected item.
class AdminLiveInspectorPane extends StatefulWidget {
  const AdminLiveInspectorPane({
    super.key,
    required this.resource,
    required this.previewRow,
    required this.repository,
    required this.onOpenDetails,
    required this.onMutated,
    required this.onClose,
    this.showHeader = true,
  });

  final AdminResource resource;
  final AdminRecord previewRow;
  final AdminRepository repository;
  final VoidCallback onOpenDetails;
  final VoidCallback onMutated;
  final VoidCallback onClose;
  final bool showHeader;

  @override
  State<AdminLiveInspectorPane> createState() => _AdminLiveInspectorPaneState();
}

class _AdminLiveInspectorPaneState extends State<AdminLiveInspectorPane> {
  Map<String, dynamic>? _recordPayload;
  AdminUserDetail? _userDetail;
  String? _error;
  bool _loading = true;
  bool _deleted = false;
  int _seq = 0;

  bool get _isUserResource => [
    AdminResource.users,
    AdminResource.subscriptions,
    AdminResource.affiliates,
  ].contains(widget.resource);

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant AdminLiveInspectorPane oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.resource != widget.resource ||
        oldWidget.previewRow.id != widget.previewRow.id) {
      _deleted = false;
      _load();
    }
  }

  Future<void> _load() async {
    final seq = ++_seq;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      if (_isUserResource) {
        final uid = widget.previewRow.userId ?? widget.previewRow.id;
        final user = await widget.repository.user(uid);
        if (mounted && seq == _seq) {
          setState(() {
            _userDetail = user;
            _recordPayload = null;
            _loading = false;
          });
        }
      } else {
        final data = await widget.repository.record(
          widget.resource,
          widget.previewRow.id,
        );
        if (mounted && seq == _seq) {
          setState(() {
            _recordPayload = data;
            _userDetail = null;
            _loading = false;
          });
        }
      }
    } catch (error) {
      if (mounted && seq == _seq) {
        setState(() {
          _error = adminError(error);
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.ui;
    final colors = theme.colors;

    if (_deleted) {
      return UiEmptyState(
        icon: Icons.check_circle_outline_rounded,
        title: 'Record updated',
        message: 'Deletion or status update recorded in audit logs.',
        action: UiButton(
          label: 'Close preview',
          variant: UiVariant.outline,
          onPressed: widget.onClose,
        ),
      );
    }

    return UiCard(
      variant: UiCardVariant.elevated,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (widget.showHeader) ...[
            Row(
              children: [
                Icon(
                  adminResourceIcon(widget.resource),
                  size: context.sz(20),
                  color: colors.primary,
                ),
                SizedBox(width: context.sp(theme.spacing.xs)),
                Expanded(
                  child: Text(
                    'Live ${widget.resource.label} Preview',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.uiText.subheading,
                  ),
                ),
                UiButton(
                  label: 'Full details',
                  leadingIcon: Icons.open_in_new_rounded,
                  variant: UiVariant.soft,
                  size: UiSize.xs,
                  onPressed: widget.onOpenDetails,
                ),
                SizedBox(width: context.sp(theme.spacing.xs)),
                UiIconButton(
                  icon: Icons.close_rounded,
                  tooltip: 'Close preview',
                  size: UiSize.xs,
                  variant: UiVariant.ghost,
                  onPressed: widget.onClose,
                ),
              ],
            ),
            SizedBox(height: context.sp(theme.spacing.sm)),
            const UiDivider(),
            SizedBox(height: context.sp(theme.spacing.sm)),
          ],
          UiAsyncView<Object>(
            loading: _loading,
            error: _error,
            data: _isUserResource ? _userDetail : _recordPayload,
            onRetry: _load,
            loadingMessage: 'Loading live preview…',
            dataBuilder: (context, _) {
              if (_isUserResource && _userDetail != null) {
                return _buildUserPreview(context, _userDetail!);
              }
              final payload = _recordPayload!;
              final record = AdminRecord(adminMap(payload['record']));
              final userId = payload['user_id']?.toString();
              final history = (payload['activity'] as List? ?? [])
                  .map((e) => AdminRecord(adminMap(e)))
                  .toList();
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  AdminRecordActions(
                    resource: widget.resource,
                    record: record,
                    userId: userId,
                    repository: widget.repository,
                    onSaved: () {
                      _load();
                      widget.onMutated();
                    },
                    onDeleted: () {
                      setState(() => _deleted = true);
                      widget.onMutated();
                    },
                  ),
                  SizedBox(height: context.sp(theme.spacing.md)),
                  AdminRecordPreviewContent(
                    resource: widget.resource,
                    record: record,
                    compact: true,
                  ),
                  if (history.isNotEmpty) ...[
                    SizedBox(height: context.sp(theme.spacing.md)),
                    Text(
                      'Recent audit trail',
                      style: context.uiText.label,
                    ),
                    SizedBox(height: context.sp(theme.spacing.xs)),
                    UiTimeline(
                      entries: [
                        for (final item in history.take(4))
                          UiTimelineEntry(
                            title: adminLabel(item.text('action')),
                            subtitle:
                                '${item.text('actor_handle')} · ${adminMap(item.values['metadata'])['reason'] ?? 'Recorded change'}',
                            timestamp: adminDate(item.values['created_at']),
                            intent: UiIntent.primary,
                          ),
                      ],
                    ),
                  ],
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildUserPreview(BuildContext context, AdminUserDetail user) {
    final theme = context.ui;
    final profile = user.profile;
    final quota = user.quota;
    final limits = adminMap(quota['limits']);
    final aiUsed = (quota['ai_queries_used'] as num?)?.toInt() ?? 0;
    final aiMax = (limits['ai_queries_per_month'] as num?)?.toInt() ?? 0;
    final notesUsed = (quota['notes_used'] as num?)?.toInt() ?? 0;
    final notesMax = (limits['notes'] as num?)?.toInt() ?? 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        UiCard(
          variant: UiCardVariant.surface,
          title: profile.title,
          subtitle: '@${profile.text('handle')} · ${profile.text('email')}',
          leading: UiAvatar(
            name: profile.title,
            imageUrl: profile.values['avatar_url']?.toString(),
          ),
          trailing: UiBadge(
            label: adminLabel(profile.status),
            intent: adminStatusIntent(profile.status),
          ),
          child: Wrap(
            spacing: context.sp(theme.spacing.xs),
            runSpacing: context.sp(theme.spacing.xs),
            children: [
              UiBadge(
                label: 'Plan: ${adminLabel(user.tier)}',
                intent: UiIntent.primary,
                size: UiSize.xs,
              ),
              UiBadge(
                label: 'Role: ${adminLabel(profile.text('role'))}',
                size: UiSize.xs,
              ),
              UiBadge(
                label:
                    'Last sign-in: ${adminDate(user.values['last_sign_in_at'])}',
                size: UiSize.xs,
              ),
            ],
          ),
        ),
        SizedBox(height: context.sp(theme.spacing.md)),
        if (user.counts.isNotEmpty) ...[
          Text('Activity & Content Footprint', style: context.uiText.label),
          SizedBox(height: context.sp(theme.spacing.xs)),
          UiBarList(
            items: [
              for (final entry in user.counts.entries)
                UiBarListItem(
                  label: adminLabel(entry.key),
                  value: (entry.value as num?)?.toInt() ?? 0,
                  icon: Icons.bar_chart_rounded,
                ),
            ],
          ),
          SizedBox(height: context.sp(theme.spacing.md)),
        ],
        if (aiMax > 0 || notesMax > 0) ...[
          Text('Live Plan Utilization', style: context.uiText.label),
          SizedBox(height: context.sp(theme.spacing.xs)),
          if (aiMax > 0) ...[
            UiProgressBar(
              value: (aiUsed / aiMax).clamp(0.0, 1.0),
              label: 'AI Monthly Queries ($aiUsed / $aiMax)',
            ),
            SizedBox(height: context.sp(theme.spacing.sm)),
          ],
          if (notesMax > 0)
            UiProgressBar(
              value: (notesUsed / notesMax).clamp(0.0, 1.0),
              label: 'Notes Allowance ($notesUsed / $notesMax)',
            ),
          SizedBox(height: context.sp(theme.spacing.md)),
        ],
        UiButton(
          label: 'Open full user console',
          leadingIcon: Icons.manage_accounts_outlined,
          onPressed: widget.onOpenDetails,
        ),
      ],
    );
  }
}
