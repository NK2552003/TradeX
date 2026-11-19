import 'package:alphajournal/core/app-ui/app_ui.dart';
import 'package:alphajournal/core/config/record_access.dart';
import 'package:alphajournal/core/config/customer_data_policy.dart';
import 'package:alphajournal/core/data/demo_data_source.dart';
import 'package:alphajournal/features/notes/data/notes_repository.dart';
import 'package:alphajournal/features/journal/data/journal_repository.dart';
import 'package:alphajournal/features/strategies/data/strategies_repository.dart';

class WorkspaceAttachmentService {
  Future<List<AppWritingPostAttachment>> ownedRecords() async {
    final results = await Future.wait([
      NotesRepositoryScope.repository.fetchAll(),
      JournalRepositoryScope.repository.fetchAll(),
      StrategiesRepositoryScope.repository.fetchAll(),
    ]);
    return [
      for (final note in results[0].cast<AppNote>())
        if (RecordAccess.owns(note.userId)) AppWritingPostAttachment.note(note),
      for (final trade in results[1].cast<AppTrade>())
        if (RecordAccess.owns(trade.userId))
          AppWritingPostAttachment.journal(trade),
      for (final strategy in results[2].cast<AppStrategy>())
        if (RecordAccess.owns(strategy.userId))
          AppWritingPostAttachment.strategy(strategy),
    ];
  }

  Future<AppWritingPostAttachment?> resolve(
    AppLinkRef source, {
    bool requireOwner = false,
  }) async {
    switch (source.kind) {
      case AppLinkKind.note:
        final record =
            await NotesRepositoryScope.repository.getById(source.id) ??
            (CustomerDataPolicy.allowDemo
                ? DemoDataSource.instance
                      .notes()
                      .where((note) => note.id == source.id)
                      .firstOrNull
                : null);
        if (record == null || (!requireOwner && !record.isPublic)) return null;
        if (requireOwner) RecordAccess.requireOwner(record.userId);
        return AppWritingPostAttachment.note(record);
      case AppLinkKind.journal:
        final record =
            await JournalRepositoryScope.repository.getById(source.id) ??
            (CustomerDataPolicy.allowDemo
                ? DemoDataSource.instance
                      .trades()
                      .where((trade) => trade.id == source.id)
                      .firstOrNull
                : null);
        if (record == null || (!requireOwner && !record.isPublic)) return null;
        if (requireOwner) RecordAccess.requireOwner(record.userId);
        return AppWritingPostAttachment.journal(record);
      case AppLinkKind.strategy:
        final record =
            await StrategiesRepositoryScope.repository.getById(source.id) ??
            (CustomerDataPolicy.allowDemo
                ? DemoDataSource.instance
                      .strategies()
                      .where((strategy) => strategy.id == source.id)
                      .firstOrNull
                : null);
        if (record == null || (!requireOwner && !record.isPublic)) return null;
        if (requireOwner) RecordAccess.requireOwner(record.userId);
        return AppWritingPostAttachment.strategy(record);
      default:
        return null;
    }
  }

  Future<void> setVisibility(AppLinkRef source, bool isPublic) async {
    switch (source.kind) {
      case AppLinkKind.note:
        await NotesRepositoryScope.repository.setVisibility(
          source.id,
          isPublic,
        );
      case AppLinkKind.journal:
        await JournalRepositoryScope.repository.setVisibility(
          source.id,
          isPublic,
        );
      case AppLinkKind.strategy:
        await StrategiesRepositoryScope.repository.setVisibility(
          source.id,
          isPublic,
        );
      default:
        throw StateError('This record cannot be published.');
    }
  }

  Future<AppWritingPostAttachment> create({
    required AppLinkKind kind,
    required String title,
    required String content,
    String? ticker,
    double? entry,
    double? quantity,
  }) async {
    if (kind == AppLinkKind.journal) {
      if (ticker == null ||
          ticker.isEmpty ||
          entry == null ||
          !entry.isFinite ||
          entry <= 0 ||
          quantity == null ||
          !quantity.isFinite ||
          quantity <= 0) {
        throw StateError(
          'A trade needs a ticker, positive entry price and quantity.',
        );
      }
      final saved = await JournalRepositoryScope.repository.create(
        AppTrade(
          id: '',
          title: title,
          ticker: ticker,
          side: AppSide.long,
          entry: entry,
          exit: null,
          size: quantity,
          content: content,
          openedAt: DateTime.now(),
        ),
      );
      return AppWritingPostAttachment.journal(saved);
    }
    if (kind == AppLinkKind.strategy) {
      final saved = await StrategiesRepositoryScope.repository.create(
        AppStrategy(
          id: '',
          name: title,
          summary: content,
          content: content,
          linkedTickers: ticker == null ? [] : [ticker],
        ),
      );
      return AppWritingPostAttachment.strategy(saved);
    }
    return createNote(title: title, content: content, ticker: ticker);
  }

  Future<AppWritingPostAttachment> createNote({
    required String title,
    required String content,
    String? ticker,
  }) async {
    final now = DateTime.now();
    final saved = await NotesRepositoryScope.repository.create(
      AppNote(
        id: '',
        title: title,
        content: content,
        createdAt: now,
        updatedAt: now,
        linkedTickers: ticker == null ? [] : [ticker],
      ),
    );
    return AppWritingPostAttachment.note(saved);
  }
}
