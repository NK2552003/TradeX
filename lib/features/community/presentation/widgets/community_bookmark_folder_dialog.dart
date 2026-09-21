import 'package:flutter/material.dart';
import 'package:tradex/core/app-ui/app_ui.dart';
import 'package:tradex/core/flutter-ui/flutter_ui.dart';
import 'package:tradex/features/community/presentation/widgets/community_design.dart';

/// Modal dialog for organizing saved posts into custom bookmark folders/collections.
class CommunityBookmarkFolderDialog extends StatefulWidget {
  const CommunityBookmarkFolderDialog({
    super.key,
    required this.postId,
    required this.onFolderSelected,
  });

  final String postId;
  final ValueChanged<String> onFolderSelected;

  static Future<String?> show(BuildContext context, {required String postId}) {
    return showDialog<String>(
      context: context,
      builder: (ctx) => CommunityDensityScope(
        child: CommunityBookmarkFolderDialog(
          postId: postId,
          onFolderSelected: (folder) => Navigator.of(ctx).pop(folder),
        ),
      ),
    );
  }

  @override
  State<CommunityBookmarkFolderDialog> createState() =>
      _CommunityBookmarkFolderDialogState();
}

class _CommunityBookmarkFolderDialogState
    extends State<CommunityBookmarkFolderDialog> {
  final List<String> _folders = [
    'All Bookmarks',
    'Swing Setups',
    'Options Flow',
    'Macro & Earnings',
    'Educational Threads',
  ];
  String? _selectedFolder = 'All Bookmarks';
  bool _isCreatingNew = false;
  final TextEditingController _newFolderController = TextEditingController();

  @override
  void dispose() {
    _newFolderController.dispose();
    super.dispose();
  }

  void _addFolder() {
    final text = _newFolderController.text.trim();
    if (text.isNotEmpty && !_folders.contains(text)) {
      setState(() {
        _folders.add(text);
        _selectedFolder = text;
        _isCreatingNew = false;
        _newFolderController.clear();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.ui;
    final colors = theme.colors;

    return Dialog(
      backgroundColor: colors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(context.sz(16)),
        side: BorderSide(color: colors.border),
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: context.sz(400)),
        child: Padding(
          padding: EdgeInsets.all(context.sp(20)),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Save to Collection',
                    style: context.uiText.heading.copyWith(
                      fontWeight: FontWeight.w700,
                      color: colors.foreground,
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

              // Folder list
              ...List.generate(_folders.length, (idx) {
                final folder = _folders[idx];
                final isSelected = folder == _selectedFolder;
                return InkWell(
                  onTap: () => setState(() => _selectedFolder = folder),
                  borderRadius: BorderRadius.circular(context.sz(8)),
                  child: Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: context.sp(12),
                      vertical: context.sp(10),
                    ),
                    margin: EdgeInsets.only(bottom: context.sp(6)),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? colors.primary.withValues(alpha: 0.1)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(context.sz(8)),
                      border: Border.all(
                        color: isSelected
                            ? colors.primary.withValues(alpha: 0.5)
                            : colors.border,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.folder_outlined,
                          size: context.sz(18),
                          color: isSelected
                              ? colors.primary
                              : colors.foregroundMuted,
                        ),
                        SizedBox(width: context.sp(10)),
                        Expanded(
                          child: Text(
                            folder,
                            style: context.uiText.body.copyWith(
                              fontWeight: isSelected
                                  ? FontWeight.w600
                                  : FontWeight.w400,
                              color: isSelected
                                  ? colors.primary
                                  : colors.foreground,
                            ),
                          ),
                        ),
                        if (isSelected)
                          Icon(
                            Icons.check,
                            size: context.sz(16),
                            color: colors.primary,
                          ),
                      ],
                    ),
                  ),
                );
              }),

              // New folder input or button
              if (_isCreatingNew) ...[
                SizedBox(height: context.sp(8)),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _newFolderController,
                        autofocus: true,
                        style: context.uiText.body.copyWith(
                          color: colors.foreground,
                        ),
                        decoration: InputDecoration(
                          hintText: 'New folder name...',
                          hintStyle: context.uiText.body.copyWith(
                            color: colors.foregroundMuted,
                          ),
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: context.sp(12),
                            vertical: context.sp(8),
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(context.sz(8)),
                            borderSide: BorderSide(color: colors.primary),
                          ),
                        ),
                        onSubmitted: (_) => _addFolder(),
                      ),
                    ),
                    SizedBox(width: context.sp(8)),
                    UiButton(
                      label: 'Add',
                      variant: UiVariant.primary,
                      size: UiSize.sm,
                      onPressed: _addFolder,
                    ),
                  ],
                ),
              ] else ...[
                SizedBox(height: context.sp(6)),
                UiButton(
                  label: '+ Create New Collection',
                  variant: UiVariant.ghost,
                  size: UiSize.sm,
                  onPressed: () => setState(() => _isCreatingNew = true),
                ),
              ],
              SizedBox(height: context.sp(20)),

              // Save button
              UiButton(
                label: 'Save Bookmark',
                variant: UiVariant.primary,
                onPressed: () {
                  if (_selectedFolder != null) {
                    widget.onFolderSelected(_selectedFolder!);
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
