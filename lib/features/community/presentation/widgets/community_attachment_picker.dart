import 'package:flutter/material.dart';
import 'package:tradex/core/app-ui/app_ui.dart';
import 'package:tradex/features/community/data/community_repository.dart';
import 'package:tradex/features/community/presentation/widgets/community_attachment_tile.dart';

/// Modal picker allowing traders to select a Writing Desk record (Note, Trade Journal, Strategy)
/// to attach to a community post.
///
/// Automatically presents as a bottom sheet on mobile and a structured dialog on desktop.
class CommunityAttachmentPicker extends StatefulWidget {
  const CommunityAttachmentPicker({super.key, required this.repository});

  final CommunityRepository repository;

  /// Displays the attachment picker adaptively (bottom sheet on mobile, dialog on desktop)
  /// and returns the selected [AppWritingPostAttachment], or null if dismissed.
  static Future<AppWritingPostAttachment?> show(
    BuildContext context, {
    required CommunityRepository repository,
  }) {
    final isMobile = context.uiRes.isMobile;

    if (isMobile) {
      return showModalBottomSheet<AppWritingPostAttachment>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (BuildContext ctx) => FractionallySizedBox(
          heightFactor: 0.85,
          child: Container(
            decoration: BoxDecoration(
              color: ctx.uiColors.surface,
              borderRadius: BorderRadius.vertical(
                top: Radius.circular(ctx.sp(ctx.ui.radii.lg)),
              ),
            ),
            child: CommunityAttachmentPicker(repository: repository),
          ),
        ),
      );
    }

    return showDialog<AppWritingPostAttachment>(
      context: context,
      builder: (BuildContext ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: EdgeInsets.all(ctx.sp(ctx.ui.spacing.lg)),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: ctx.sz(580),
            maxHeight: ctx.sz(640),
          ),
          child: Container(
            decoration: BoxDecoration(
              color: ctx.uiColors.surface,
              borderRadius: ctx.radius(ctx.ui.radii.lg),
              border: Border.all(
                color: ctx.uiColors.border,
                width: ctx.ui.borders.hairline,
              ),
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.25),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: CommunityAttachmentPicker(repository: repository),
          ),
        ),
      ),
    );
  }

  @override
  State<CommunityAttachmentPicker> createState() =>
      _CommunityAttachmentPickerState();
}

class _CommunityAttachmentPickerState extends State<CommunityAttachmentPicker> {
  String _selectedKind = 'all';
  String _searchQuery = '';

  static const List<UiToggleOption<String>> _kindOptions =
      <UiToggleOption<String>>[
        UiToggleOption<String>(value: 'all', label: 'All Records'),
        UiToggleOption<String>(value: 'note', label: 'Notes'),
        UiToggleOption<String>(value: 'journal', label: 'Journal'),
        UiToggleOption<String>(value: 'strategy', label: 'Strategies'),
      ];

  @override
  Widget build(BuildContext context) {
    final UiTheme theme = context.ui;
    final String query = _searchQuery.trim().toLowerCase();

    final List<AppWritingPostAttachment> records = widget
        .repository
        .attachableRecords
        .where((r) {
          if (_selectedKind != 'all') {
            if (r.kind.name != _selectedKind) return false;
          }
          if (query.isEmpty) return true;

          return r.source.title.toLowerCase().contains(query) ||
              r.excerpt.toLowerCase().contains(query) ||
              (r.primaryTicker ?? '').toLowerCase().contains(query) ||
              r.tags.any((t) => t.toLowerCase().contains(query));
        })
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        // Header
        Padding(
          padding: EdgeInsets.fromLTRB(
            context.sp(theme.spacing.md),
            context.sp(theme.spacing.md),
            context.sp(theme.spacing.md),
            context.sp(theme.spacing.sm),
          ),
          child: Row(
            children: <Widget>[
              Icon(
                Icons.link_rounded,
                color: theme.colors.primary,
                size: context.sz(20),
              ),
              SizedBox(width: context.sp(theme.spacing.xs)),
              Text(
                'Attach Workspace Record',
                style: context.uiText.heading.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              UiIconButton(
                icon: Icons.close_rounded,
                size: UiSize.sm,
                tooltip: 'Close',
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
        ),

        // Controls: Kind Filter + Search Field
        Padding(
          padding: EdgeInsets.symmetric(
            horizontal: context.sp(theme.spacing.md),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              UiToggleGroup<String>(
                value: _selectedKind,
                variant: UiToggleGroupVariant.segmented,
                size: UiSize.sm,
                options: _kindOptions,
                onChanged: (val) => setState(() => _selectedKind = val),
              ),
              SizedBox(height: context.sp(theme.spacing.sm)),
              UiSearchField(
                value: _searchQuery,
                hintText: 'Search title, ticker, tags, or excerpt...',
                onChanged: (val) => setState(() => _searchQuery = val),
              ),
              SizedBox(height: context.sp(theme.spacing.xs)),
              // Quick creation action row
              Row(
                children: <Widget>[
                  Text(
                    'Need to create one first?',
                    style: context.uiText.caption.copyWith(
                      color: theme.colors.foregroundSubtle,
                      fontSize: context.fs(11),
                    ),
                  ),
                  const Spacer(),
                  UiButton(
                    label: '+ Note',
                    size: UiSize.xs,
                    variant: UiVariant.ghost,
                    onPressed: () => _openQuickCreate(context, AppLinkKind.note),
                  ),
                  UiButton(
                    label: '+ Journal',
                    size: UiSize.xs,
                    variant: UiVariant.ghost,
                    onPressed: () => _openQuickCreate(context, AppLinkKind.journal),
                  ),
                  UiButton(
                    label: '+ Strategy',
                    size: UiSize.xs,
                    variant: UiVariant.ghost,
                    onPressed: () => _openQuickCreate(context, AppLinkKind.strategy),
                  ),
                ],
              ),
            ],
          ),
        ),

        SizedBox(height: context.sp(theme.spacing.sm)),
        const UiDivider(),

        // Candidates List
        Expanded(
          child: records.isEmpty
              ? Center(
                  child: Padding(
                    padding: EdgeInsets.all(context.sp(theme.spacing.lg)),
                    child: UiEmptyState(
                      icon: Icons.find_in_page_outlined,
                      title: 'No matching records',
                      message:
                          'Create a note, journal trade, or strategy above to attach it to your post immediately.',
                      actionLabel: '+ Quick Create Note',
                      onActionPressed: () => _openQuickCreate(context, AppLinkKind.note),
                    ),
                  ),
                )
              : ListView.separated(
                  padding: EdgeInsets.all(context.sp(theme.spacing.md)),
                  itemCount: records.length,
                  separatorBuilder: (BuildContext ctx, int i) =>
                      SizedBox(height: ctx.sp(theme.spacing.sm)),
                  itemBuilder: (BuildContext ctx, int index) {
                    final item = records[index];
                    return CommunityAttachmentTile(
                      attachment: item,
                      onTap: () => Navigator.of(context).pop(item),
                    );
                  },
                ),
        ),
      ],
    );
  }

  void _openQuickCreate(BuildContext context, AppLinkKind kind) {
    final titleCtrl = TextEditingController();
    final excerptCtrl = TextEditingController();
    final tickerCtrl = TextEditingController();
    final UiTheme theme = context.ui;

    final String kindLabel = switch (kind) {
      AppLinkKind.note => 'Note',
      AppLinkKind.journal => 'Trade Journal',
      AppLinkKind.strategy => 'Strategy Playbook',
      _ => 'Record',
    };

    showDialog<void>(
      context: context,
      builder: (dialogCtx) => UiDialog(
        title: 'Create $kindLabel',
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            UiInput(
              label: 'Title',
              hintText: 'e.g. BankNifty 50000 Call Scalp Setup',
              controller: titleCtrl,
            ),
            SizedBox(height: context.sp(theme.spacing.sm)),
            UiInput(
              label: 'Primary Ticker (Optional)',
              hintText: 'e.g. BANKNIFTY',
              controller: tickerCtrl,
            ),
            SizedBox(height: context.sp(theme.spacing.sm)),
            UiTextarea(
              label: 'Summary / Thesis',
              hintText: 'Key reasoning, risk parameters, and execution rules...',
              controller: excerptCtrl,
              maxLines: 3,
            ),
          ],
        ),
        actions: <Widget>[
          UiButton(
            label: 'Cancel',
            variant: UiVariant.ghost,
            size: UiSize.sm,
            onPressed: () => Navigator.of(dialogCtx).pop(),
          ),
          UiButton(
            label: 'Create & Attach',
            variant: UiVariant.primary,
            size: UiSize.sm,
            onPressed: () {
              final title = titleCtrl.text.trim().isEmpty
                  ? 'Untitled $kindLabel'
                  : titleCtrl.text.trim();
              final excerpt = excerptCtrl.text.trim().isEmpty
                  ? 'Detailed workspace $kindLabel record created on ${DateTime.now().toString().substring(0, 10)}.'
                  : excerptCtrl.text.trim();
              final ticker = tickerCtrl.text.trim().isEmpty
                  ? null
                  : tickerCtrl.text.trim().toUpperCase();

              final newRecord = AppWritingPostAttachment.manual(
                source: AppLinkRef(
                  kind: kind,
                  id: 'rec_${DateTime.now().millisecondsSinceEpoch}',
                  title: title,
                ),
                excerpt: excerpt,
                primaryTicker: ticker,
                updatedAt: DateTime.now(),
                tags: ticker != null ? [ticker] : const [],
              );

              widget.repository.addAttachableRecord(newRecord);
              Navigator.of(dialogCtx).pop();
              Navigator.of(context).pop(newRecord);
            },
          ),
        ],
      ),
    );
  }
}
