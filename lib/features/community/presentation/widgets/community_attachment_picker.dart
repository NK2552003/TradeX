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
            ],
          ),
        ),

        SizedBox(height: context.sp(theme.spacing.sm)),
        UiDivider(),

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
                          'Create notes, journal trades, or strategies in your workspace to attach them to your posts.',
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
}
