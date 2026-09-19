import 'package:flutter/material.dart';
import 'package:tradex/core/app-ui/app_ui.dart';
import 'package:tradex/core/flutter-ui/flutter_ui.dart';
import 'package:tradex/features/community/data/community_repository.dart';

/// Modal dialog allowing traders to add, remove, and customize home feed watchlist tabs.
class CommunityFeedCustomizerDialog extends StatefulWidget {
  const CommunityFeedCustomizerDialog({
    super.key,
    required this.repository,
  });

  final CommunityRepository repository;

  static Future<void> show(
    BuildContext context, {
    required CommunityRepository repository,
  }) {
    return showDialog<void>(
      context: context,
      builder: (BuildContext ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: EdgeInsets.all(ctx.sp(ctx.ui.spacing.md)),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: ctx.sz(460)),
          child: Container(
            padding: EdgeInsets.all(ctx.sp(ctx.ui.spacing.md)),
            decoration: BoxDecoration(
              color: ctx.uiColors.surface,
              borderRadius: ctx.radius(ctx.ui.radii.lg),
              border: Border.all(
                color: ctx.uiColors.border,
                width: ctx.ui.borders.hairline,
              ),
            ),
            child: CommunityFeedCustomizerDialog(repository: repository),
          ),
        ),
      ),
    );
  }

  @override
  State<CommunityFeedCustomizerDialog> createState() =>
      _CommunityFeedCustomizerDialogState();
}

class _CommunityFeedCustomizerDialogState
    extends State<CommunityFeedCustomizerDialog> {
  String _newTabInput = '';

  @override
  Widget build(BuildContext context) {
    final UiTheme theme = context.ui;
    final tabs = widget.repository.customFeedTabs;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        // Header
        Row(
          children: <Widget>[
            Icon(
              Icons.tab_rounded,
              color: theme.colors.primary,
              size: context.sz(20),
            ),
            SizedBox(width: context.sp(theme.spacing.xs)),
            Text(
              'Customize Feed Tabs',
              style: context.uiText.heading.copyWith(fontWeight: FontWeight.w700),
            ),
            const Spacer(),
            UiIconButton(
              icon: Icons.close_rounded,
              size: UiSize.xs,
              tooltip: 'Close',
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ),
        SizedBox(height: context.sp(theme.spacing.xs)),
        Text(
          'Add custom watchlist tabs to your community feed to track specific assets or strategies.',
          style: context.uiText.caption.copyWith(
            color: theme.colors.foregroundMuted,
          ),
        ),
        SizedBox(height: context.sp(theme.spacing.md)),

        // Input row
        Row(
          children: <Widget>[
            Expanded(
              child: UiInput(
                value: _newTabInput,
                hintText: 'e.g. NIFTY, Scalping, Forex...',
                onChanged: (val) => setState(() => _newTabInput = val),
              ),
            ),
            SizedBox(width: context.sp(theme.spacing.xs)),
            UiButton(
              label: 'Add',
              variant: UiVariant.primary,
              onPressed: _newTabInput.trim().isEmpty
                  ? null
                  : () {
                      final text = _newTabInput.trim();
                      if (text.isNotEmpty) {
                        widget.repository.addCustomFeedTab(text);
                        setState(() => _newTabInput = '');
                      }
                    },
            ),
          ],
        ),
        SizedBox(height: context.sp(theme.spacing.md)),

        // Active custom tabs list
        Text(
          'Active Custom Tabs',
          style: context.uiText.bodyStrong.copyWith(fontWeight: FontWeight.w700),
        ),
        SizedBox(height: context.sp(theme.spacing.xs)),

        if (tabs.isEmpty)
          Padding(
            padding: EdgeInsets.symmetric(vertical: context.sp(theme.spacing.md)),
            child: Text(
              'No custom tabs added yet.',
              style: context.uiText.caption.copyWith(
                color: theme.colors.foregroundSubtle,
              ),
            ),
          )
        else
          Wrap(
            spacing: context.sp(theme.spacing.xs),
            runSpacing: context.sp(theme.spacing.xs),
            children: <Widget>[
              for (final tab in tabs)
                Chip(
                  label: Text(tab),
                  backgroundColor: theme.colors.surfaceMuted,
                  deleteIcon: const Icon(Icons.close_rounded, size: 16),
                  onDeleted: () {
                    widget.repository.removeCustomFeedTab(tab);
                    setState(() {});
                  },
                ),
            ],
          ),

        SizedBox(height: context.sp(theme.spacing.lg)),
        UiButton(
          label: 'Done',
          variant: UiVariant.secondary,
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
    );
  }
}
