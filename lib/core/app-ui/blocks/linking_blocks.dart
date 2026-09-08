import 'package:flutter/material.dart';

import '../../flutter-ui/flutter_ui.dart';
import '../models/app_models.dart';
import '../motion/app_motion.dart';
import '../theme/app_tokens.dart';

/// Linking blocks — the one vocabulary all three note surfaces use to show and
/// edit their edges.
///
/// Trader notes, journal entries and strategy playbooks each link to the other
/// two. Rendering that with per-feature widgets would mean six near-identical
/// panels drifting apart, so everything here speaks [AppLinkRef] and
/// [AppLinkBundle] and knows nothing about which surface it is on. A journal
/// entry's "Linked notes" panel and a playbook's are the same widget with a
/// different bundle.
///
/// Nothing in this file resolves an edge. `core/linking/link_graph.dart` turns
/// ids into refs; these widgets only draw them.

// ── Chip ─────────────────────────────────────────────────────────────────────

/// One edge, inline. Used in card footers and document headers where a full row
/// would cost more vertical space than the link is worth.
class AppLinkChip extends StatelessWidget {
  const AppLinkChip({
    super.key,
    required this.ref,
    this.onTap,
    this.onRemove,
    this.showKindIcon = true,
    this.size = UiSize.sm,
  });

  final AppLinkRef ref;
  final VoidCallback? onTap;

  /// Renders the chip's remove affordance. Null hides it, which is how the
  /// read-only surfaces (preview, public feed) reuse this widget.
  final VoidCallback? onRemove;
  final bool showKindIcon;
  final UiSize size;

  @override
  Widget build(BuildContext context) => UiBadge(
    label: ref.title,
    icon: showKindIcon ? ref.icon ?? ref.kind.icon : null,
    intent: ref.missing ? UiIntent.warning : ref.intent ?? ref.kind.intent,
    variant: ref.missing ? UiBadgeVariant.outline : UiBadgeVariant.soft,
    size: size,
    maxWidth: context.sz(220),
    tooltip: ref.missing
        ? '${ref.kind.label} ${ref.id} could not be found'
        : <String?>[ref.kind.label, ref.subtitle, ref.meta]
              .whereType<String>()
              .join(' · '),
    onTap: onTap,
    onRemove: onRemove,
  );
}

// ── Row ──────────────────────────────────────────────────────────────────────

/// One edge, as a full row: icon, title, subtitle, trailing meta.
///
/// A broken edge renders as a warning row rather than disappearing. A link the
/// trader can see is broken is a link they can fix; a link that silently vanishes
/// is data loss they will never notice.
class AppLinkRefTile extends StatelessWidget {
  const AppLinkRefTile({
    super.key,
    required this.ref,
    this.onTap,
    this.onRemove,
    this.selected = false,
    this.dense = false,
    this.trailing,
  });

  final AppLinkRef ref;
  final VoidCallback? onTap;
  final VoidCallback? onRemove;
  final bool selected;
  final bool dense;

  /// Replaces the default trailing meta text.
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final UiTheme theme = context.ui;
    final UiColors c = theme.colors;
    final bool broken = ref.missing;
    final Color accent = broken
        ? c.warning
        : (ref.intent ?? ref.kind.intent).color(context);
    final double pad = context.sp(dense ? theme.spacing.sm : theme.spacing.md);

    return AppHoverLift(
      enabled: onTap != null,
      child: Material(
        color: selected ? c.surfaceMuted : Colors.transparent,
        borderRadius: context.radius(theme.radii.md),
        child: InkWell(
          onTap: onTap,
          borderRadius: context.radius(theme.radii.md),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: pad,
              vertical: context.sp(dense ? theme.spacing.xs : theme.spacing.sm),
            ),
            child: Row(
              children: <Widget>[
                Container(
                  width: context.sz(dense ? 26 : 32),
                  height: context.sz(dense ? 26 : 32),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.12),
                    borderRadius: context.radius(theme.radii.sm),
                  ),
                  child: Icon(
                    broken
                        ? Icons.link_off_rounded
                        : ref.icon ?? ref.kind.icon,
                    size: context.sz(dense ? 14 : 16),
                    color: accent,
                  ),
                ),
                SizedBox(width: context.sp(theme.spacing.sm)),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        ref.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.uiText.body.copyWith(
                          color: broken ? c.warning : c.foreground,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (ref.subtitle != null && ref.subtitle!.isNotEmpty)
                        Text(
                          ref.subtitle!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: context.uiText.caption.copyWith(
                            color: c.foregroundMuted,
                          ),
                        ),
                    ],
                  ),
                ),
                if (trailing != null)
                  trailing!
                else if (ref.meta != null && ref.meta!.isNotEmpty) ...<Widget>[
                  SizedBox(width: context.sp(theme.spacing.sm)),
                  Text(
                    ref.meta!,
                    style: context.uiText.caption.copyWith(color: accent),
                  ),
                ],
                if (onRemove != null) ...<Widget>[
                  SizedBox(width: context.sp(theme.spacing.xs)),
                  UiIconButton(
                    icon: Icons.close_rounded,
                    size: UiSize.xs,
                    tooltip: 'Unlink',
                    onPressed: onRemove,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Section ──────────────────────────────────────────────────────────────────

/// One kind's worth of edges, with a count and an optional "Link…" action.
class AppLinkSection extends StatelessWidget {
  const AppLinkSection({
    super.key,
    required this.kind,
    required this.refs,
    this.onOpen,
    this.onRemove,
    this.onAdd,
    this.dense = false,
    this.emptyMessage,
    this.maxVisible,
  });

  final AppLinkKind kind;
  final List<AppLinkRef> refs;
  final void Function(AppLinkRef ref)? onOpen;
  final void Function(AppLinkRef ref)? onRemove;
  final VoidCallback? onAdd;
  final bool dense;

  /// Shown instead of the rows when there is nothing linked. Worth writing per
  /// surface: "No trades yet" means something different on a playbook than on a
  /// note.
  final String? emptyMessage;

  /// Caps the rows and appends a "+N more" line. Used in side rails where the
  /// panel competes with the document for height.
  final int? maxVisible;

  @override
  Widget build(BuildContext context) {
    final UiTheme theme = context.ui;
    final int cap = maxVisible ?? refs.length;
    final List<AppLinkRef> shown = refs.take(cap).toList(growable: false);
    final int hidden = refs.length - shown.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        AppLinkSectionHeader(
          label: kind.plural,
          icon: kind.icon,
          count: refs.length,
          onAdd: onAdd,
          addTooltip: 'Link ${kind.label.toLowerCase()}',
        ),
        SizedBox(height: context.sp(theme.spacing.xs)),
        if (shown.isEmpty)
          Padding(
            padding: EdgeInsets.symmetric(
              horizontal: context.sp(theme.spacing.md),
              vertical: context.sp(theme.spacing.sm),
            ),
            child: Text(
              emptyMessage ?? 'Nothing linked yet.',
              style: context.uiText.caption.copyWith(
                color: theme.colors.foregroundMuted,
              ),
            ),
          )
        else
          for (final AppLinkRef ref in shown)
            AppLinkRefTile(
              ref: ref,
              dense: dense,
              onTap: onOpen == null || ref.missing
                  ? null
                  : () => onOpen!(ref),
              onRemove: onRemove == null ? null : () => onRemove!(ref),
            ),
        if (hidden > 0)
          Padding(
            padding: EdgeInsets.only(
              left: context.sp(theme.spacing.md),
              top: context.sp(theme.spacing.xs),
            ),
            child: Text(
              '+$hidden more',
              style: context.uiText.caption.copyWith(
                color: theme.colors.foregroundMuted,
              ),
            ),
          ),
      ],
    );
  }
}

/// The label row above a group of links or index rows.
class AppLinkSectionHeader extends StatelessWidget {
  const AppLinkSectionHeader({
    super.key,
    required this.label,
    this.icon,
    this.count,
    this.onAdd,
    this.addTooltip,
    this.trailing,
  });

  final String label;
  final IconData? icon;
  final int? count;
  final VoidCallback? onAdd;
  final String? addTooltip;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final UiTheme theme = context.ui;
    final UiColors c = theme.colors;
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: context.sp(theme.spacing.md),
        vertical: context.sp(theme.spacing.xs),
      ),
      child: Row(
        children: <Widget>[
          if (icon != null) ...<Widget>[
            Icon(icon, size: context.sz(13), color: c.foregroundMuted),
            SizedBox(width: context.sp(theme.spacing.xs)),
          ],
          Text(label.toUpperCase(), style: uiOverline(context)),
          if (count != null) ...<Widget>[
            SizedBox(width: context.sp(theme.spacing.xs)),
            Text(
              '$count',
              style: context.uiText.caption.copyWith(color: c.foregroundMuted),
            ),
          ],
          const Spacer(),
          ?trailing,
          if (onAdd != null)
            UiIconButton(
              icon: Icons.add_link_rounded,
              size: UiSize.xs,
              tooltip: addTooltip ?? 'Link',
              onPressed: onAdd,
            ),
        ],
      ),
    );
  }
}

// ── Panel ────────────────────────────────────────────────────────────────────

/// Everything linked to one record, grouped by kind.
///
/// This is the widget that makes the three features one workspace: the same
/// panel appears on a note, on a journal entry and on a playbook, and in every
/// case it lists the other two kinds plus the instruments involved.
class AppLinkedRecordsPanel extends StatelessWidget {
  const AppLinkedRecordsPanel({
    super.key,
    required this.bundle,
    this.title = 'Linked',
    this.subtitle,
    this.onOpen,
    this.onRemove,
    this.onAddNote,
    this.onAddJournal,
    this.onAddStrategy,
    this.onAddTicker,
    this.dense = false,
    this.maxVisiblePerKind,
    this.showEmptyKinds = true,
    this.hideKinds = const <AppLinkKind>{},
    this.emptyMessages = const <AppLinkKind, String>{},
    this.card = true,
  });

  final AppLinkBundle bundle;
  final String title;
  final String? subtitle;
  final void Function(AppLinkRef ref)? onOpen;
  final void Function(AppLinkRef ref)? onRemove;
  final VoidCallback? onAddNote;
  final VoidCallback? onAddJournal;
  final VoidCallback? onAddStrategy;
  final VoidCallback? onAddTicker;
  final bool dense;
  final int? maxVisiblePerKind;

  /// Keeps a kind's header visible with its empty message. On when the panel is
  /// an editing surface — an absent "Journal entries" header is an affordance
  /// the trader cannot find. Off in read-only contexts.
  final bool showEmptyKinds;

  /// Kinds this surface owns rather than links. A journal entry does not offer
  /// to link a ticker: its instrument is the trade's own.
  final Set<AppLinkKind> hideKinds;
  final Map<AppLinkKind, String> emptyMessages;

  /// Wrapped in a [UiCard] by default. Off when the host already owns a card,
  /// which is how the desktop rail embeds it without doubling the border.
  final bool card;

  @override
  Widget build(BuildContext context) {
    final UiTheme theme = context.ui;
    final List<Widget> sections = <Widget>[];

    void add(
      AppLinkKind kind,
      List<AppLinkRef> refs,
      VoidCallback? onAdd,
    ) {
      if (hideKinds.contains(kind)) return;
      if (refs.isEmpty && !showEmptyKinds) return;
      if (sections.isNotEmpty) {
        sections.add(SizedBox(height: context.sp(theme.spacing.md)));
      }
      sections.add(
        AppLinkSection(
          kind: kind,
          refs: refs,
          dense: dense,
          maxVisible: maxVisiblePerKind,
          emptyMessage: emptyMessages[kind],
          onOpen: onOpen,
          onRemove: onRemove,
          onAdd: onAdd,
        ),
      );
    }

    add(AppLinkKind.strategy, bundle.strategies, onAddStrategy);
    add(AppLinkKind.journal, bundle.journal, onAddJournal);
    add(AppLinkKind.note, bundle.notes, onAddNote);
    add(AppLinkKind.ticker, bundle.tickers, onAddTicker);

    final Widget body = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Padding(
          padding: EdgeInsets.symmetric(
            horizontal: context.sp(theme.spacing.md),
          ),
          child: Row(
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(title, style: context.uiText.subheading),
                    if (subtitle != null)
                      Text(
                        subtitle!,
                        style: context.uiText.caption.copyWith(
                          color: theme.colors.foregroundMuted,
                        ),
                      ),
                  ],
                ),
              ),
              UiBadge(
                label: '${bundle.length}',
                icon: Icons.hub_outlined,
                variant: UiBadgeVariant.outline,
                size: UiSize.xs,
                tooltip: '${bundle.length} linked records',
              ),
            ],
          ),
        ),
        SizedBox(height: context.sp(theme.spacing.sm)),
        if (sections.isEmpty)
          Padding(
            padding: EdgeInsets.all(context.sp(theme.spacing.md)),
            child: UiEmptyState(
              icon: Icons.hub_outlined,
              title: 'Nothing linked yet',
              message:
                  'Attach a playbook, a trade or a note and this record stops '
                  'being an island.',
              action: onAddStrategy == null
                  ? null
                  : UiButton(
                      label: 'Link a playbook',
                      leadingIcon: Icons.add_link_rounded,
                      variant: UiVariant.secondary,
                      size: UiSize.sm,
                      onPressed: onAddStrategy,
                    ),
            ),
          )
        else
          ...sections,
      ],
    );

    if (!card) return body;
    return UiCard(
      padding: EdgeInsets.symmetric(vertical: context.sp(theme.spacing.md)),
      child: body,
    );
  }
}

// ── Picker ───────────────────────────────────────────────────────────────────

/// Picks records to link.
///
/// [options] is already filtered by the caller to exclude what is linked, so the
/// picker never offers a duplicate. Returns the chosen ids, or null if the trader
/// backed out — an empty list means "I deselected everything", which is a
/// different answer and one the caller may want to act on.
///
/// Mobile gets a bottom sheet, desktop a centred modal, courtesy of
/// [UiDialog.show]. Both are the same widget; only the container differs.
Future<List<String>?> showAppLinkPicker(
  BuildContext context, {
  required AppLinkKind kind,
  required List<AppLinkRef> options,
  Set<String> initiallySelected = const <String>{},
  bool multiSelect = true,
  String? title,
  String? emptyMessage,
}) => UiDialog.show<List<String>>(
  context,
  maxWidth: 560,
  child: _AppLinkPicker(
    kind: kind,
    options: options,
    initiallySelected: initiallySelected,
    multiSelect: multiSelect,
    title: title ?? 'Link ${kind.plural.toLowerCase()}',
    emptyMessage: emptyMessage,
  ),
);

class _AppLinkPicker extends StatefulWidget {
  const _AppLinkPicker({
    required this.kind,
    required this.options,
    required this.initiallySelected,
    required this.multiSelect,
    required this.title,
    this.emptyMessage,
  });

  final AppLinkKind kind;
  final List<AppLinkRef> options;
  final Set<String> initiallySelected;
  final bool multiSelect;
  final String title;
  final String? emptyMessage;

  @override
  State<_AppLinkPicker> createState() => _AppLinkPickerState();
}

class _AppLinkPickerState extends State<_AppLinkPicker> {
  final ScrollController _scroll = ScrollController();
  late final Set<String> _selected = <String>{...widget.initiallySelected};
  String _query = '';

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  List<AppLinkRef> get _visible {
    final String q = _query.trim().toLowerCase();
    if (q.isEmpty) return widget.options;
    return widget.options
        .where(
          (AppLinkRef r) =>
              r.title.toLowerCase().contains(q) ||
              (r.subtitle ?? '').toLowerCase().contains(q),
        )
        .toList(growable: false);
  }

  void _toggle(AppLinkRef ref) {
    if (!widget.multiSelect) {
      Navigator.of(context).pop(<String>[ref.id]);
      return;
    }
    setState(() {
      if (!_selected.remove(ref.id)) _selected.add(ref.id);
    });
  }

  @override
  Widget build(BuildContext context) {
    final UiTheme theme = context.ui;
    final UiColors c = theme.colors;
    final List<AppLinkRef> visible = _visible;
    // Bounded so a 400-entry journal does not push the actions off screen; the
    // list scrolls inside the modal instead.
    final double listHeight = context.sz(context.uiRes.isMobile ? 320 : 380);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Row(
          children: <Widget>[
            Icon(widget.kind.icon, size: context.sz(18), color: c.primary),
            SizedBox(width: context.sp(theme.spacing.sm)),
            Expanded(
              child: Text(widget.title, style: context.uiText.subheading),
            ),
            UiIconButton(
              icon: Icons.close_rounded,
              size: UiSize.sm,
              tooltip: 'Cancel',
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ),
        SizedBox(height: context.sp(theme.spacing.md)),
        UiSearchField(
          hintText: 'Search ${widget.kind.plural.toLowerCase()}…',
          value: _query,
          autofocus: !context.uiRes.isMobile,
          onChanged: (String v) => setState(() => _query = v),
        ),
        SizedBox(height: context.sp(theme.spacing.sm)),
        SizedBox(
          height: listHeight,
          child: visible.isEmpty
              ? UiEmptyState(
                  icon: widget.kind.icon,
                  title: widget.options.isEmpty
                      ? 'Nothing left to link'
                      : 'No match',
                  message: widget.options.isEmpty
                      ? widget.emptyMessage ??
                            'Every ${widget.kind.label.toLowerCase()} you have '
                                'is already attached to this record.'
                      : 'Nothing matches "$_query".',
                )
              : UiScrollbar(
                  controller: _scroll,
                  child: ListView.builder(
                    controller: _scroll,
                    primary: false,
                    itemCount: visible.length,
                    itemBuilder: (BuildContext context, int i) {
                      final AppLinkRef ref = visible[i];
                      final bool on = _selected.contains(ref.id);
                      return AppLinkRefTile(
                        ref: ref,
                        selected: on,
                        dense: true,
                        onTap: () => _toggle(ref),
                        trailing: widget.multiSelect
                            ? Icon(
                                on
                                    ? Icons.check_circle_rounded
                                    : Icons.radio_button_unchecked_rounded,
                                size: context.sz(18),
                                color: on ? c.primary : c.foregroundMuted,
                              )
                            : Icon(
                                Icons.chevron_right_rounded,
                                size: context.sz(18),
                                color: c.foregroundMuted,
                              ),
                      );
                    },
                  ),
                ),
        ),
        if (widget.multiSelect) ...<Widget>[
          SizedBox(height: context.sp(theme.spacing.md)),
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  _selected.isEmpty
                      ? 'Nothing selected'
                      : '${_selected.length} selected',
                  style: context.uiText.caption.copyWith(
                    color: c.foregroundMuted,
                  ),
                ),
              ),
              UiButton(
                label: 'Cancel',
                variant: UiVariant.ghost,
                size: UiSize.sm,
                onPressed: () => Navigator.of(context).pop(),
              ),
              SizedBox(width: context.sp(theme.spacing.sm)),
              UiButton(
                label: 'Link',
                leadingIcon: Icons.add_link_rounded,
                size: UiSize.sm,
                onPressed: () =>
                    Navigator.of(context).pop(_selected.toList(growable: false)),
              ),
            ],
          ),
        ],
      ],
    );
  }
}


// ── Health strip ─────────────────────────────────────────────────────────────

/// The workspace's link health: how connected it is, and what is not.
///
/// Deliberately not a vanity metric. The orphan list is the actionable half —
/// a trade with no plan and no write-up is the one that gets repeated — so the
/// strip leads with counts and ends with the records to go fix.
class AppLinkGraphStrip extends StatelessWidget {
  const AppLinkGraphStrip({
    super.key,
    required this.noteCount,
    required this.journalCount,
    required this.strategyCount,
    required this.edgeCount,
    required this.coverage,
    this.orphans = const <AppLinkRef>[],
    this.onOpen,
    this.onSeeAllOrphans,
    this.loading = false,
  });

  final int noteCount;
  final int journalCount;
  final int strategyCount;
  final int edgeCount;

  /// Share of journal entries carrying a write-up, 0–1.
  final double coverage;
  final List<AppLinkRef> orphans;
  final void Function(AppLinkRef ref)? onOpen;
  final VoidCallback? onSeeAllOrphans;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final UiTheme theme = context.ui;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        UiStatStrip(
          minCellWidth: 150,
          stats: <UiStat>[
            UiStat(
              label: 'Links',
              value: loading ? '—' : '$edgeCount',
              icon: Icons.hub_outlined,
              intent: UiIntent.primary,
              hint: 'Across notes, trades and playbooks',
            ),
            UiStat(
              label: 'Written up',
              value: loading ? '—' : AppTokens.percent(coverage * 100),
              icon: Icons.edit_note_rounded,
              intent: coverage >= 0.8
                  ? UiIntent.success
                  : coverage >= 0.5
                  ? UiIntent.warning
                  : UiIntent.danger,
              hint: 'Journal entries with a story',
            ),
            UiStat(
              label: 'Playbooks',
              value: loading ? '—' : '$strategyCount',
              icon: AppLinkKind.strategy.icon,
              hint: '$journalCount trades logged',
            ),
            UiStat(
              label: 'Notes',
              value: loading ? '—' : '$noteCount',
              icon: AppLinkKind.note.icon,
              hint: 'Research, reviews and cheat sheets',
            ),
          ],
        ),
        if (orphans.isNotEmpty) ...<Widget>[
          SizedBox(height: context.sp(theme.spacing.md)),
          UiCallout(
            intent: UiIntent.warning,
            icon: Icons.link_off_rounded,
            title: '${orphans.length} record'
                '${orphans.length == 1 ? '' : 's'} with nothing attached',
            message:
                'A trade with no plan and no note is the one that gets '
                'repeated. Link them while the reasoning is still fresh.',
            action: onSeeAllOrphans == null
                ? null
                : UiButton(
                    label: 'Review',
                    variant: UiVariant.ghost,
                    size: UiSize.sm,
                    onPressed: onSeeAllOrphans,
                  ),
          ),
          SizedBox(height: context.sp(theme.spacing.sm)),
          Wrap(
            spacing: context.sp(theme.spacing.xs),
            runSpacing: context.sp(theme.spacing.xs),
            children: <Widget>[
              for (final AppLinkRef ref in orphans)
                AppLinkChip(
                  ref: ref,
                  onTap: onOpen == null ? null : () => onOpen!(ref),
                ),
            ],
          ),
        ],
      ],
    );
  }
}
