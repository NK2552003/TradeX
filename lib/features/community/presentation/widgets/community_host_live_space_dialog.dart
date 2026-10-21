import 'package:flutter/material.dart';
import 'package:tradex/core/app-ui/app_ui.dart';
import 'package:tradex/core/flutter-ui/flutter_ui.dart';
import 'package:tradex/features/community/data/community_repository.dart';
import 'package:tradex/features/community/models/community_models.dart';
import 'package:tradex/features/community/presentation/widgets/community_design.dart';
import 'package:tradex/features/community/presentation/widgets/community_live_room_sheet.dart';

/// Modal dialog allowing verified traders to host or schedule a Live Audio Space.
class CommunityHostLiveSpaceDialog extends StatefulWidget {
  const CommunityHostLiveSpaceDialog({
    super.key,
    required this.repository,
  });

  final CommunityRepository repository;

  static Future<void> show(
    BuildContext context, {
    required CommunityRepository repository,
  }) {
    return UiDialog.show<void>(
      context,
      maxWidth: 520,
      child: CommunityDensityScope(
        child: CommunityHostLiveSpaceDialog(repository: repository),
      ),
    );
  }

  @override
  State<CommunityHostLiveSpaceDialog> createState() =>
      _CommunityHostLiveSpaceDialogState();
}

class _CommunityHostLiveSpaceDialogState
    extends State<CommunityHostLiveSpaceDialog> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _topicController = TextEditingController();
  final TextEditingController _tickerController = TextEditingController();
  final TextEditingController _entryController = TextEditingController();
  final TextEditingController _slController = TextEditingController();
  final TextEditingController _targetController = TextEditingController();
  final TextEditingController _noteController = TextEditingController();

  String _category = 'Options & Expiry';
  bool _startNow = true;
  bool _attachPinnedSetup = false;
  String _tradeSide = 'LONG';
  final List<String> _tags = <String>['#TradingFloor', '#AlphaLive'];

  static const List<String> _categories = <String>[
    'Options & Expiry',
    'Equities & Breakouts',
    'Crypto & DeFi',
    'Macro & Forex',
    'Positional & Swing',
    'Technical Analysis',
  ];

  @override
  void dispose() {
    _titleController.dispose();
    _topicController.dispose();
    _tickerController.dispose();
    _entryController.dispose();
    _slController.dispose();
    _targetController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      UiToast.warning(
        context,
        title: 'Title Required',
        message: 'Please provide a title for your Live Space.',
      );
      return;
    }

    final topic = _topicController.text.trim().isEmpty
        ? 'Live trading analysis and market execution floor'
        : _topicController.text.trim();

    LivePinnedSetup? setup;
    if (_attachPinnedSetup && _tickerController.text.trim().isNotEmpty) {
      final entry = double.tryParse(_entryController.text.trim()) ?? 100.0;
      final sl = double.tryParse(_slController.text.trim()) ?? 90.0;
      final target = double.tryParse(_targetController.text.trim()) ?? 120.0;
      setup = LivePinnedSetup(
        ticker: _tickerController.text.trim().toUpperCase(),
        side: _tradeSide,
        entry: entry,
        stopLoss: sl,
        target: target,
        note: _noteController.text.trim().isEmpty
            ? 'Key execution level discussed live on stage.'
            : _noteController.text.trim(),
      );
    }

    final room = await widget.repository.createLiveRoom(
      title: title,
      topic: topic,
      category: _category,
      pinnedSetup: setup,
      startNow: _startNow,
      scheduledFor: _startNow ? null : DateTime.now().add(const Duration(hours: 2)),
      tags: _tags,
    );

    if (!mounted) return;
    Navigator.of(context).pop();

    UiToast.success(
      context,
      title: _startNow ? 'Space Live Now' : 'Space Scheduled',
      message: _startNow
          ? 'You are now live on stage in "$title"!'
          : 'Space scheduled for today. Traders can set reminders.',
    );

    if (_startNow) {
      CommunityLiveRoomSheet.show(
        context,
        roomId: room.id,
        roomTitle: room.title,
        hostName: room.host.displayName,
        repository: widget.repository,
        listenerCount: room.listenerCount,
        pinnedSetup: room.pinnedSetup,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.ui;

    return UiDialog(
      title: 'Host a Live Audio Space',
      description:
          'Broadcast live market analysis, discuss option structures, or break down trades with your community.',
      icon: Icons.podcasts_rounded,
      intent: UiIntent.primary,
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            // Title input
            UiField(
              label: 'Space Title',
              child: UiInput(
                controller: _titleController,
                hintText: 'e.g. BankNifty Expiry Gamma Scalping & OI Read',
              ),
            ),
            SizedBox(height: context.sp(theme.spacing.sm)),

            // Topic / Agenda
            UiField(
              label: 'Agenda / Topic',
              child: UiInput(
                controller: _topicController,
                hintText: 'e.g. Discussing VWAP reclaim and trailing stop strategies',
              ),
            ),
            SizedBox(height: context.sp(theme.spacing.sm)),

            // Category select
            UiField(
              label: 'Market Category',
              child: UiSelect<String>(
                value: _category,
                options: _categories
                    .map((cat) => UiOption<String>(value: cat, label: cat))
                    .toList(),
                onChanged: (cat) => setState(() => _category = cat),
              ),
            ),
            SizedBox(height: context.sp(theme.spacing.sm)),

            // Start Immediately toggle switch
            UiSwitch(
              label: 'Go Live Immediately',
              value: _startNow,
              asCard: true,
              onChanged: (val) => setState(() => _startNow = val),
            ),
            SizedBox(height: context.sp(theme.spacing.sm)),

            // Attach Pinned Setup toggle
            Container(
              padding: EdgeInsets.all(context.sp(theme.spacing.xs)),
              decoration: BoxDecoration(
                color: theme.colors.surfaceMuted,
                borderRadius: BorderRadius.circular(theme.radii.md),
                border: Border.all(color: theme.colors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  UiSwitch(
                    label: 'Pin High-Conviction Setup on Stage',
                    value: _attachPinnedSetup,
                    onChanged: (val) => setState(() => _attachPinnedSetup = val),
                  ),
                  if (_attachPinnedSetup) ...<Widget>[
                    SizedBox(height: context.sp(theme.spacing.sm)),
                    Row(
                      children: <Widget>[
                        Expanded(
                          flex: 2,
                          child: UiField(
                            label: 'Ticker',
                            child: UiInput(
                              controller: _tickerController,
                              hintText: 'NIFTY 24,850 CE',
                            ),
                          ),
                        ),
                        SizedBox(width: context.sp(theme.spacing.xs)),
                        Expanded(
                          child: UiField(
                            label: 'Side',
                            child: UiSelect<String>(
                              value: _tradeSide,
                              options: const <UiOption<String>>[
                                UiOption<String>(value: 'LONG', label: 'LONG'),
                                UiOption<String>(value: 'SHORT', label: 'SHORT'),
                              ],
                              onChanged: (s) => setState(() => _tradeSide = s),
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: context.sp(theme.spacing.xs)),
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: UiField(
                            label: 'Entry (₹)',
                            child: UiInput(
                              controller: _entryController,
                              hintText: '142.50',
                            ),
                          ),
                        ),
                        SizedBox(width: context.sp(theme.spacing.xs)),
                        Expanded(
                          child: UiField(
                            label: 'Stop Loss (₹)',
                            child: UiInput(
                              controller: _slController,
                              hintText: '118.00',
                            ),
                          ),
                        ),
                        SizedBox(width: context.sp(theme.spacing.xs)),
                        Expanded(
                          child: UiField(
                            label: 'Target (₹)',
                            child: UiInput(
                              controller: _targetController,
                              hintText: '210.00',
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: context.sp(theme.spacing.xs)),
                    UiField(
                      label: 'Setup Note',
                      child: UiInput(
                        controller: _noteController,
                        hintText: 'Breakout above 15-min swing high with OI volume spike',
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
      actions: <Widget>[
        UiButton(
          label: 'Cancel',
          variant: UiVariant.ghost,
          onPressed: () => Navigator.of(context).pop(),
        ),
        UiButton(
          label: _startNow ? 'Start Space Now' : 'Schedule Space',
          leadingIcon: Icons.podcasts_rounded,
          variant: UiVariant.solid,
          intent: UiIntent.primary,
          onPressed: _submit,
        ),
      ],
    );
  }
}
