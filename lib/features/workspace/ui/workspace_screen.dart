import 'dart:async';

import 'package:flutter/material.dart';
import 'package:tradex/core/app-ui/app_ui.dart';
// Required unified primitive import for every writing workspace surface.
// ignore: unnecessary_import
import 'package:tradex/core/flutter-ui/flutter_ui.dart';
import 'package:tradex/features/journal/data/journal_repository.dart';
import 'package:tradex/features/notes/data/notes_repository.dart';
import 'package:tradex/features/strategies/data/strategies_repository.dart';

/// The Writing Desk landing page. Individual tools intentionally contain no
/// dashboard analytics; their shared status lives here.
class WorkspaceScreen extends StatefulWidget {
  const WorkspaceScreen({super.key, required this.onOpenFeature});

  final ValueChanged<String> onOpenFeature;

  @override
  State<WorkspaceScreen> createState() => WorkspaceScreenState();
}

class WorkspaceScreenState extends State<WorkspaceScreen> {
  final JournalRepository _journal = JournalRepositoryScope.repository;
  final StrategiesRepository _strategies = StrategiesRepositoryScope.repository;
  final NotesRepository _notes = NotesRepositoryScope.repository;

  StreamSubscription<List<AppTrade>>? _journalSub;
  StreamSubscription<List<AppStrategy>>? _strategySub;
  StreamSubscription<List<AppNote>>? _noteSub;
  List<AppTrade> _entries = const <AppTrade>[];
  List<AppStrategy> _playbooks = const <AppStrategy>[];
  List<AppNote> _allNotes = const <AppNote>[];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _journalSub = _journal.watchAll().listen((List<AppTrade> value) {
      if (!mounted) return;
      setState(() {
        _entries = value;
        _loading = false;
      });
    });
    _strategySub = _strategies.watchAll().listen((List<AppStrategy> value) {
      if (mounted) setState(() => _playbooks = value);
    });
    _noteSub = _notes.watchAll().listen((List<AppNote> value) {
      if (mounted) setState(() => _allNotes = value);
    });
  }

  @override
  void dispose() {
    _journalSub?.cancel();
    _strategySub?.cancel();
    _noteSub?.cancel();
    super.dispose();
  }

  int get _openTrades => _entries.where((AppTrade t) => t.isOpen).length;
  int get _livePlaybooks => _playbooks
      .where((AppStrategy s) => s.status == AppStrategyStatus.live)
      .length;
  int get _privateNotes => _allNotes.where((AppNote n) => !n.isPublic).length;
  List<AppNote> get _publicNotes =>
      _allNotes.where((AppNote n) => n.isPublic).toList(growable: false);
  int get _publicLinks => _publicNotes.fold<int>(
    0,
    (int total, AppNote note) =>
        total +
        note.linkedJournalIds.length +
        (note.strategyId == null ? 0 : 1),
  );

  @override
  Widget build(BuildContext context) {
    final UiTheme theme = context.ui;
    return UiPage(
      maxWidth: 1320,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text('Plan, execute, remember.', style: context.uiText.title),
          SizedBox(height: context.sp(theme.spacing.xs)),
          Text(
            'Your playbooks, trade records, and research notes in one connected workspace.',
            style: context.uiText.body.copyWith(
              color: theme.colors.foregroundMuted,
            ),
          ),
          SizedBox(height: context.sp(theme.spacing.lg)),
          UiCardGrid(
            mobileColumns: 1,
            tabletColumns: 2,
            desktopColumns: 2,
            largeColumns: 2,
            childAspectRatio: context.uiRes.isMobile ? 2.4 : 3.1,
            children: <Widget>[
              UiMetricCard(
                label: 'Journal entries',
                value: _loading ? '—' : '${_entries.length}',
                icon: Icons.receipt_long_outlined,
                onTap: () => widget.onOpenFeature('journal'),
              ),
              UiMetricCard(
                label: 'Open trades',
                value: _loading ? '—' : '$_openTrades',
                icon: Icons.schedule_rounded,
                onTap: () => widget.onOpenFeature('journal'),
              ),
              UiMetricCard(
                label: 'Live playbooks',
                value: _loading ? '—' : '$_livePlaybooks',
                icon: Icons.play_circle_outline_rounded,
                onTap: () => widget.onOpenFeature('strategies'),
              ),
              UiMetricCard(
                label: 'Published note links',
                value: _loading ? '—' : '$_publicLinks',
                icon: Icons.hub_outlined,
                onTap: () => widget.onOpenFeature('notes'),
              ),
            ],
          ),
          SizedBox(height: context.sp(theme.spacing.lg)),
          UiCardGrid(
            mobileColumns: 1,
            tabletColumns: 2,
            desktopColumns: 2,
            largeColumns: 2,
            childAspectRatio: 1.15,
            children: <Widget>[
              _DeskCard(
                title: 'Journal',
                subtitle: 'Execute and review',
                icon: Icons.receipt_long_outlined,
                count: '${_entries.length} entries · $_openTrades open',
                items: _entries
                    .take(3)
                    .map((AppTrade trade) => trade.displayTitle)
                    .toList(growable: false),
                onOpen: () => widget.onOpenFeature('journal'),
              ),
              _DeskCard(
                title: 'Strategies',
                subtitle: 'Define the playbook',
                icon: Icons.account_tree_outlined,
                count: '${_playbooks.length} playbooks · $_livePlaybooks live',
                items: _playbooks
                    .take(3)
                    .map((AppStrategy strategy) => strategy.name)
                    .toList(growable: false),
                onOpen: () => widget.onOpenFeature('strategies'),
              ),
              _DeskCard(
                title: 'Private notes',
                subtitle: 'Research for your eyes only',
                icon: Icons.lock_outline_rounded,
                count: '$_privateNotes private notes',
                items: _allNotes
                    .where((AppNote note) => !note.isPublic)
                    .take(3)
                    .map((AppNote note) => note.title)
                    .toList(growable: false),
                onOpen: () => widget.onOpenFeature('notes'),
              ),
              _DeskCard(
                title: 'Published notes',
                subtitle: 'Shared with their linked context',
                icon: Icons.public_rounded,
                count:
                    '${_publicNotes.length} public · $_publicLinks linked records',
                items: _publicNotes
                    .take(3)
                    .map((AppNote note) {
                      final int links =
                          note.linkedJournalIds.length +
                          (note.strategyId == null ? 0 : 1);
                      return '${note.title} · $links linked';
                    })
                    .toList(growable: false),
                onOpen: () => widget.onOpenFeature('notes'),
              ),
            ],
          ),
          SizedBox(height: context.uiPageBottomInset),
        ],
      ),
    );
  }
}

class _DeskCard extends StatelessWidget {
  const _DeskCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.count,
    required this.items,
    required this.onOpen,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final String count;
  final List<String> items;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final UiTheme theme = context.ui;
    return UiCard(
      onTap: onOpen,
      variant: UiCardVariant.outlined,
      hoverLift: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(icon, color: theme.colors.primary),
              SizedBox(width: context.sp(theme.spacing.sm)),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(title, style: context.uiText.subheading),
                    Text(
                      subtitle,
                      style: context.uiText.caption.copyWith(
                        color: theme.colors.foregroundMuted,
                      ),
                    ),
                  ],
                ),
              ),
              UiIconButton(
                icon: Icons.arrow_forward_rounded,
                tooltip: 'Open $title',
                variant: UiVariant.ghost,
                onPressed: onOpen,
              ),
            ],
          ),
          SizedBox(height: context.sp(theme.spacing.md)),
          UiBadge(label: count, variant: UiBadgeVariant.soft),
          SizedBox(height: context.sp(theme.spacing.md)),
          const UiDivider(),
          SizedBox(height: context.sp(theme.spacing.sm)),
          for (final String item in items) ...<Widget>[
            Text(
              item.trim().isEmpty ? 'Untitled' : item,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.uiText.body,
            ),
            SizedBox(height: context.sp(theme.spacing.xs)),
          ],
          if (items.isEmpty)
            Text(
              'Nothing here yet.',
              style: context.uiText.body.copyWith(
                color: theme.colors.foregroundMuted,
              ),
            ),
        ],
      ),
    );
  }
}
