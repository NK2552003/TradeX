import 'package:flutter/material.dart';
import 'package:alphajournal/core/app-ui/app_ui.dart';
import 'package:alphajournal/core/flutter-ui/flutter_ui.dart';

import '../../data/admin_repository.dart';
import '../../models/admin_records.dart';
import 'admin_action_dialog.dart';

class AdminRecordActions extends StatelessWidget {
  const AdminRecordActions({
    super.key,
    required this.resource,
    required this.record,
    required this.repository,
    required this.onSaved,
    this.userId,
    this.onDeleted,
  });
  final AdminResource resource;
  final AdminRecord record;
  final AdminRepository repository;
  final VoidCallback onSaved;
  final VoidCallback? onDeleted;
  final String? userId;

  Future<void> _apply(
    BuildContext context,
    String title,
    String action,
    Map<String, dynamic> value, {
    bool destructive = false,
  }) async {
    if (await runAdminAction(
      context,
      title: title,
      destructive: destructive,
      submit: (reason) => repository.apply(
        action: action,
        reason: reason,
        userId: userId,
        recordId: record.id,
        value: value,
      ),
    )) {
      onSaved();
    }
  }

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: context.sp(context.ui.spacing.sm),
    runSpacing: context.sp(context.ui.spacing.sm),
    children: [
      if (resource == AdminResource.posts ||
          resource == AdminResource.comments) ...[
        for (final decision in [
          ('Approve', 'approved', UiIntent.success),
          ('Reject', 'rejected', UiIntent.danger),
          ('Return to review', 'pending', UiIntent.warning),
        ])
          if (record.text('moderation_status') != decision.$2)
            UiButton(
              label: decision.$1,
              intent: decision.$3,
              variant: UiVariant.outline,
              onPressed: () => _apply(
                context,
                '${decision.$1} ${resource == AdminResource.posts ? 'post' : 'comment'}',
                resource == AdminResource.posts
                    ? 'moderate_post'
                    : 'moderate_comment',
                {'status': decision.$2},
                destructive: decision.$2 == 'rejected',
              ),
            ),
      ],
      if (resource == AdminResource.posts) ...[
        UiButton(
          label: record.flag('is_pinned') ? 'Unpin post' : 'Pin post',
          variant: UiVariant.outline,
          onPressed: () => _apply(
            context,
            'Update pinned post',
            'post_options',
            {'is_pinned': !record.flag('is_pinned')},
          ),
        ),
        UiButton(
          label: record.flag('is_featured')
              ? 'Remove featured status'
              : 'Feature post',
          variant: UiVariant.outline,
          onPressed: () => _apply(
            context,
            'Update featured post',
            'post_options',
            {'is_featured': !record.flag('is_featured')},
          ),
        ),
      ],
      if (resource == AdminResource.applications &&
          ['pending', 'pending_review'].contains(record.status)) ...[
        UiButton(
          label: 'Approve affiliate',
          intent: UiIntent.success,
          onPressed: () => _apply(
            context,
            'Approve affiliate application',
            'review_application',
            {'status': 'approved'},
          ),
        ),
        UiButton(
          label: 'Reject application',
          intent: UiIntent.danger,
          variant: UiVariant.outline,
          onPressed: () => _apply(
            context,
            'Reject affiliate application',
            'review_application',
            {'status': 'rejected'},
            destructive: true,
          ),
        ),
      ],
      if ([
        AdminResource.notes,
        AdminResource.journal,
        AdminResource.strategies,
        AdminResource.messages,
        AdminResource.ai,
      ].contains(resource)) ...[
        UiButton(
          label: record.flag('admin_hidden')
              ? 'Restore record'
              : 'Restrict record',
          intent: record.flag('admin_hidden')
              ? UiIntent.success
              : UiIntent.danger,
          variant: UiVariant.outline,
          onPressed: () => _apply(
            context,
            record.flag('admin_hidden') ? 'Restore record' : 'Restrict record',
            record.flag('admin_hidden') ? 'restore_record' : 'restrict_record',
            {'resource': resource.apiName},
            destructive: !record.flag('admin_hidden'),
          ),
        ),
        if ([
              AdminResource.notes,
              AdminResource.journal,
              AdminResource.strategies,
            ].contains(resource) &&
            (record.flag('is_public') || record.text('visibility') == 'public'))
          UiButton(
            label: 'Make private',
            variant: UiVariant.outline,
            onPressed: () => _apply(
              context,
              'Make writing record private',
              'make_private',
              {'resource': resource.apiName},
            ),
          ),
      ],
      if ([
        AdminResource.posts,
        AdminResource.comments,
        AdminResource.notes,
        AdminResource.journal,
        AdminResource.strategies,
        AdminResource.messages,
        AdminResource.ai,
      ].contains(resource))
        UiButton(
          label: 'Delete record',
          intent: UiIntent.danger,
          variant: UiVariant.outline,
          onPressed: () async {
            if (await runAdminAction(
              context,
              title: 'Permanently delete record',
              description:
                  'Delete “${record.title}” and its linked child records. This cannot be undone. Activity history is retained.',
              confirmation: record.id,
              destructive: true,
              submit: (reason) => repository.apply(
                action: 'delete_record',
                userId: userId,
                recordId: record.id,
                value: {'resource': resource.apiName},
                reason: reason,
              ),
            )) {
              (onDeleted ?? onSaved)();
            }
          },
        ),
      if (resource == AdminResource.payouts &&
          ['pending', 'processing'].contains(record.status))
        for (final action in [
          if (record.status == 'pending') ('Mark processing', 'processing'),
          ('Record completed payout', 'paid'),
          ('Mark payout failed', 'failed'),
          ('Cancel payout', 'cancelled'),
        ])
          UiButton(
            label: action.$1,
            variant: UiVariant.outline,
            onPressed: () async {
              var reference = '';
              if (await runAdminAction(
                context,
                title: action.$1,
                description: action.$2 == 'paid'
                    ? 'Use this after completing the transfer. Enter its provider or bank reference to record the payout.'
                    : 'Failed or cancelled reserved payouts return the amount to the partner’s available balance.',
                additionalContent: action.$2 == 'paid'
                    ? UiInput(
                        label: 'Completed transfer reference',
                        onChanged: (value) => reference = value,
                      )
                    : null,
                submit: (reason) => repository.apply(
                  action: 'payout_status',
                  userId: userId,
                  recordId: record.id,
                  reason: reason,
                  value: {
                    'status': action.$2,
                    if (action.$2 == 'paid')
                      'transaction_reference': reference.trim(),
                  },
                ),
              )) {
                onSaved();
              }
            },
          ),
      if (resource == AdminResource.deletions &&
          [
            'pending',
            'grace_period',
            'data_purged',
            'failed',
            'processing',
          ].contains(record.status)) ...[
        if (['pending', 'grace_period'].contains(record.status))
          UiButton(
            label: 'Cancel deletion request',
            variant: UiVariant.outline,
            onPressed: () => _apply(
              context,
              'Cancel deletion request',
              'cancel_deletion',
              {},
            ),
          ),
        UiButton(
          label: ['failed', 'processing'].contains(record.status)
              ? 'Retry account deletion'
              : 'Permanently delete account',
          intent: UiIntent.danger,
          onPressed: () async {
            if (await runAdminAction(
              context,
              title: 'Permanently delete account',
              destructive: true,
              confirmation: record.text('user_handle'),
              description:
                  'Delete the account and its personal records and files. This cannot be undone. External billing must be cancelled with the provider first.',
              submit: (reason) => repository.deleteAccount(
                requestId: record.id,
                handle: record.text('user_handle'),
                reason: reason,
              ),
            )) {
              (onDeleted ?? onSaved)();
            }
          },
        ),
      ],
    ],
  );
}
