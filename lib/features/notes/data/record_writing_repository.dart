import 'dart:io';

import 'package:tradex/core/app-ui/app_ui.dart';
import 'package:tradex/features/journal/data/journal_repository.dart';
import 'package:tradex/features/strategies/data/strategies_repository.dart';

/// An editor projection of an existing record, never a second persisted note.
/// Only the title and prose are written back. Execution, performance, visibility,
/// and links continue to belong to the source record's detail form.
class RecordWritingDocument {
  const RecordWritingDocument({
    required this.source,
    required this.note,
    required this.save,
    required this.upload,
    required this.resolveImage,
  });
  final AppLinkRef source;
  final AppNote note;
  final Future<AppNote> Function(AppNote draft) save;
  final Future<String> Function(File file) upload;
  final Future<String> Function(String ref) resolveImage;
}

class RecordWritingRepository {
  RecordWritingRepository({
    JournalRepository? journal,
    StrategiesRepository? strategies,
  }) : journal = journal ?? JournalRepositoryScope.repository,
       strategies = strategies ?? StrategiesRepositoryScope.repository;
  final JournalRepository journal;
  final StrategiesRepository strategies;

  Future<RecordWritingDocument> open(AppLinkKind kind, String id) async {
    if (kind == AppLinkKind.journal) {
      final record = await journal.getById(id);
      if (record == null) throw StateError('This trade no longer exists.');
      return RecordWritingDocument(
        source: AppLinkRef(kind: kind, id: id, title: record.displayTitle),
        note: tradeNote(record),
        save: (draft) async {
          final latest = await journal.getById(id);
          if (latest == null) {
            throw StateError(
              'This trade was deleted. Your draft is still open.',
            );
          }
          return tradeNote(
            await journal.update(
              latest.copyWith(title: draft.title, content: draft.content),
            ),
          );
        },
        upload: (file) => journal.uploadAttachment(id, file),
        resolveImage: journal.resolveAttachmentUrl,
      );
    }
    if (kind == AppLinkKind.strategy) {
      final record = await strategies.getById(id);
      if (record == null) throw StateError('This strategy no longer exists.');
      return RecordWritingDocument(
        source: AppLinkRef(kind: kind, id: id, title: record.name),
        note: strategyNote(record),
        save: (draft) async {
          final latest = await strategies.getById(id);
          if (latest == null) {
            throw StateError(
              'This strategy was deleted. Your draft is still open.',
            );
          }
          return strategyNote(
            await strategies.update(
              latest.copyWith(name: draft.title, content: draft.content),
            ),
          );
        },
        upload: (file) => strategies.uploadAttachment(id, file),
        resolveImage: strategies.resolveAttachmentUrl,
      );
    }
    throw ArgumentError('Only reviews and playbooks have source writing.');
  }

  static AppNote tradeNote(AppTrade record) => AppNote(
    id: record.id,
    title: record.displayTitle,
    content: record.content,
    createdAt: record.openedAt,
    updatedAt: record.editedAt,
    tags: record.tags,
    linkedTickers: [record.ticker],
    linkedJournalIds: [record.id],
    strategyId: record.strategyId,
    strategyName: record.strategy,
  ).withDerivedCounts();

  static AppNote strategyNote(AppStrategy record) => AppNote(
    id: record.id,
    title: record.name,
    content: record.content,
    createdAt: record.createdAt ?? record.updatedAt ?? DateTime(2000),
    updatedAt: record.updatedAt ?? record.createdAt ?? DateTime(2000),
    tags: record.tags,
    linkedTickers: record.linkedTickers,
    strategyId: record.id,
    strategyName: record.name,
    linkedJournalIds: record.linkedJournalIds,
  ).withDerivedCounts();
}
