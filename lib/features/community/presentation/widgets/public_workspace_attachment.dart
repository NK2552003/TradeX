import 'dart:async';
import 'package:alphajournal/features/notes/data/notes_repository.dart';
import 'package:alphajournal/features/journal/data/journal_repository.dart';
import 'package:alphajournal/features/strategies/data/strategies_repository.dart';
import 'package:flutter/material.dart';
import 'package:alphajournal/core/app-ui/app_ui.dart';
import 'package:alphajournal/features/community/data/workspace_attachment_service.dart';
import 'community_attachment_tile.dart';

/// Revalidates public visibility before rendering any saved attachment text.
class PublicWorkspaceAttachment extends StatefulWidget {
  const PublicWorkspaceAttachment({
    super.key,
    required this.attachment,
    this.onTap,
    this.dense = false,
  });
  final AppWritingPostAttachment attachment;
  final VoidCallback? onTap;
  final bool dense;
  @override
  State<PublicWorkspaceAttachment> createState() =>
      _PublicWorkspaceAttachmentState();
}

class _PublicWorkspaceAttachmentState extends State<PublicWorkspaceAttachment>
    with WidgetsBindingObserver {
  late Future<AppWritingPostAttachment?> _future;
  StreamSubscription<dynamic>? _sourceSubscription;
  String? _sourceSignature;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _reload();
    _watchSource();
  }

  void _reload() {
    _future = WorkspaceAttachmentService().resolve(widget.attachment.source);
  }

  void _watchSource() {
    _sourceSubscription?.cancel();
    _sourceSignature = null;
    final source = widget.attachment.source;
    switch (source.kind) {
      case AppLinkKind.note:
        _sourceSubscription = NotesRepositoryScope.repository.watchAll().listen((
          records,
        ) {
          final record = records.where((r) => r.id == source.id).firstOrNull;
          _sourceChanged(
            record?.isPublic,
            record == null
                ? null
                : '${record.userId}:${record.title}:${record.content.hashCode}:${record.isPublic}',
          );
        });
      case AppLinkKind.journal:
        _sourceSubscription = JournalRepositoryScope.repository.watchAll().listen((
          records,
        ) {
          final record = records.where((r) => r.id == source.id).firstOrNull;
          _sourceChanged(
            record?.isPublic,
            record == null
                ? null
                : '${record.userId}:${record.title}:${record.content.hashCode}:${record.isPublic}',
          );
        });
      case AppLinkKind.strategy:
        _sourceSubscription = StrategiesRepositoryScope.repository
            .watchAll()
            .listen((records) {
              final record = records
                  .where((r) => r.id == source.id)
                  .firstOrNull;
              _sourceChanged(
                record?.isPublic,
                record == null
                    ? null
                    : '${record.userId}:${record.name}:${record.content.hashCode}:${record.isPublic}',
              );
            });
      default:
        break;
    }
  }

  void _sourceChanged(bool? isPublic, String? signature) {
    if (!mounted || signature == _sourceSignature) return;
    _sourceSignature = signature;
    setState(() {
      if (isPublic == false) {
        _future = Future.value(null);
      } else {
        _reload();
      }
    });
  }

  @override
  void didUpdateWidget(covariant PublicWorkspaceAttachment oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.attachment != widget.attachment) {
      _reload();
      if (oldWidget.attachment.source.id != widget.attachment.source.id ||
          oldWidget.attachment.source.kind != widget.attachment.source.kind) {
        _watchSource();
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) setState(_reload);
  }

  @override
  void dispose() {
    _sourceSubscription?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      FutureBuilder<AppWritingPostAttachment?>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const UiSkeleton(height: 72);
          }
          final record = snapshot.data;
          if (snapshot.hasError || record == null) {
            return UiEmptyState(
              title: 'Attachment unavailable',
              message:
                  'The record is private, removed, or could not be verified.',
              action: UiButton(
                label: 'Retry',
                variant: UiVariant.ghost,
                onPressed: () => setState(_reload),
              ),
            );
          }
          return CommunityAttachmentTile(
            attachment: record,
            dense: widget.dense,
            onTap: widget.onTap,
          );
        },
      );
}
