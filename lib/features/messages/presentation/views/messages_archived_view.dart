import 'package:flutter/material.dart';
import 'package:tradex/core/app-ui/app_ui.dart';
import 'package:tradex/features/messages/data/messages_repository.dart';
import 'package:tradex/features/messages/models/messages_models.dart';
import 'package:tradex/features/messages/presentation/widgets/messages_widgets.dart';

/// Archived conversations. Rows read as muted inbox tiles; each can be reopened
/// (unarchived) or opened in place. Content comes from
/// [MessagesRepository.archivedThreads].
class MessagesArchivedView extends StatefulWidget {
  const MessagesArchivedView({
    super.key,
    required this.repository,
    this.onOpenThread,
  });

  final MessagesRepository repository;
  final void Function(MessageThread thread)? onOpenThread;

  @override
  State<MessagesArchivedView> createState() => _MessagesArchivedViewState();
}

class _MessagesArchivedViewState extends State<MessagesArchivedView> {
  @override
  void initState() {
    super.initState();
    widget.repository.addListener(_onRepo);
  }

  @override
  void didUpdateWidget(covariant MessagesArchivedView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.repository != oldWidget.repository) {
      oldWidget.repository.removeListener(_onRepo);
      widget.repository.addListener(_onRepo);
    }
  }

  void _onRepo() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    widget.repository.removeListener(_onRepo);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final UiTheme theme = context.ui;
    final List<MessageThread> archived = widget.repository.archivedThreads;

    if (archived.isEmpty) {
      return const MessagesEmptyState(
        icon: Icons.archive_outlined,
        title: 'Nothing archived',
        message: 'Archived conversations stay out of your inbox but keep their '
            'full history.',
      );
    }

    return ListView(
      padding: EdgeInsets.only(
        left: context.sp(theme.spacing.sm),
        right: context.sp(theme.spacing.sm),
        top: context.sp(theme.spacing.xs),
        bottom: context.sp(theme.spacing.xl),
      ),
      children: <Widget>[
        for (final MessageThread t in archived)
          _ArchivedRow(
            trailing: UiIconButton(
              icon: Icons.unarchive_outlined,
              tooltip: 'Unarchive',
              variant: UiVariant.soft,
              onPressed: () => widget.repository.toggleArchive(t.id),
            ),
            child: ConversationTile(
              thread: t,
              typing: false,
              onTap: () => widget.onOpenThread?.call(t),
            ),
          ),
      ],
    );
  }
}

/// A conversation tile with a trailing action button (unarchive). Kept local
/// and minimal — a full swipe gesture is not needed for the archive list.
class _ArchivedRow extends StatelessWidget {
  const _ArchivedRow({required this.child, required this.trailing});

  final Widget child;
  final Widget trailing;

  @override
  Widget build(BuildContext context) {
    final UiTheme theme = context.ui;
    return Row(
      children: <Widget>[
        Expanded(child: child),
        SizedBox(width: context.sp(theme.spacing.xxs)),
        trailing,
        SizedBox(width: context.sp(theme.spacing.xs)),
      ],
    );
  }
}
