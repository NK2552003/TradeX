import 'package:tradex/core/linking/link_graph.dart';
import 'package:flutter/material.dart';
import 'package:tradex/core/app-ui/app_ui.dart';
import 'package:tradex/features/ai_assistant/data/ai_assistant_repository.dart';
import 'package:tradex/features/ai_assistant/models/ai_assistant_models.dart';
import 'package:tradex/features/ai_assistant/presentation/overlays/ai_chart_analysis_dialog.dart';
import 'package:tradex/features/ai_assistant/presentation/overlays/ai_create_sheet.dart';
import 'package:tradex/features/ai_assistant/presentation/overlays/ai_persona_dialog.dart';
import 'package:tradex/features/ai_assistant/presentation/views/ai_chat_view.dart';
import 'package:tradex/features/ai_assistant/presentation/views/ai_create_view.dart';
import 'package:tradex/features/ai_assistant/presentation/views/ai_history_view.dart';
import 'package:tradex/features/ai_assistant/presentation/views/ai_insights_view.dart';
import 'package:tradex/features/ai_assistant/presentation/widgets/ai_assistant_widgets.dart';
import 'package:tradex/features/auth/models/auth_user_role.dart';

/// The AI Assistant shell — three-tier responsive copilot layout.
///
/// **Mobile** (< 600 px):
///   - Tabbed interface: Chat / Insights / Create with a bottom segmented
///     control. History is accessible from the chat header or as a fourth tab.
///
/// **Tablet** (600–904 px):
///   - Thread history rail on the left, active chat on the right.
///
/// **Desktop** (≥ 905 px):
///   - Thread rail + chat column + insights side panel (three-column).
///
/// All content is served by [AiAssistantRepository]; this widget owns only
/// navigation and which tab / subpage is showing.
class AiAssistantRootScreen extends StatefulWidget {
  const AiAssistantRootScreen({
    super.key,
    this.userRole = UserRole.customer,
    this.currentUser,
    this.onSubpageChanged,
    this.onOpenRef,
    this.repository,
    this.searchQuery,
    this.openRequest,
    this.embedInScaffold = true,
  });

  final UserRole userRole;
  final AppTrader? currentUser;
  final void Function(String? title, IconData? icon, VoidCallback? onBack)?
      onSubpageChanged;

  /// Opens a created Writing-Desk record in its home feature. Supplied by shell.
  final void Function(AppLinkRef ref)? onOpenRef;

  /// Optional shared repository; an internal one is created if omitted.
  final AiAssistantRepository? repository;

  /// Search text pushed from the global top header.
  final String? searchQuery;

  /// True when embedded inside AppShell (avoids duplicate chrome on mobile).
  final bool embedInScaffold;
  
  /// Link request to open a specific item.
  final AppLinkOpenRequest? openRequest;

  @override
  State<AiAssistantRootScreen> createState() => AiAssistantRootScreenState();
}

class AiAssistantRootScreenState extends State<AiAssistantRootScreen> {
  late final AiAssistantRepository _repo;
  late final bool _ownsRepo;

  /// Mobile tab index: 0 = Chat, 1 = Insights, 2 = Create.
  int _mobileTab = 0;

  /// Secondary mobile panel currently pushed.
  _MobilePanel _mobilePanel = _MobilePanel.none;

  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _ownsRepo = widget.repository == null;
    _repo = widget.repository ?? AiAssistantRepository();
    _searchQuery = widget.searchQuery ?? '';
    _repo.addListener(_onRepo);
    
    if (widget.openRequest != null) {
      _applyRequest(widget.openRequest!);
    }
  }

  @override
  void didUpdateWidget(covariant AiAssistantRootScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.searchQuery != oldWidget.searchQuery &&
        widget.searchQuery != null) {
      _searchQuery = widget.searchQuery!;
    }
    
    if (widget.openRequest != null && widget.openRequest != oldWidget.openRequest) {
      _applyRequest(widget.openRequest!);
    }
    _notifySubpage();
  }
  
  void _notifySubpage() {
    if (!mounted) return;
    if (_isMobile && _mobilePanel == _MobilePanel.history) {
      widget.onSubpageChanged?.call("History", Icons.history_rounded, _closePanel);
    } else {
      widget.onSubpageChanged?.call(null, null, null);
    }
  }
  
  void _applyRequest(AppLinkOpenRequest request) {
    final String targetId = request.id;
    if (_repo.threads.any((t) => t.id == targetId)) {
      _repo.selectThread(targetId);
      setState(() {
        _mobileTab = 0;
        _mobilePanel = _MobilePanel.none;
      });
    }
  }

  void _onRepo() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _repo.removeListener(_onRepo);
    if (_ownsRepo) _repo.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Public API (GlobalKey-driven from the shell)
  // ---------------------------------------------------------------------------

  /// Pushes a search query in from the global header search field.
  void setSearchQuery(String query) {
    if (!mounted) return;
    setState(() => _searchQuery = query);
  }

  // ---------------------------------------------------------------------------
  // Navigation
  // ---------------------------------------------------------------------------

  bool get _isMobile => context.uiRes.isMobile;

  void _selectThread(String id) {
    _repo.selectThread(id);
    if (_isMobile) {
      setState(() => _mobilePanel = _MobilePanel.none);
      _mobileTab = 0; // back to chat
    }
  }

  void _openHistory() {
    setState(() => _mobilePanel = _MobilePanel.history);
    if (_isMobile) {
      _notifySubpage();
    }
  }

  void _closePanel() {
    setState(() => _mobilePanel = _MobilePanel.none);
    _notifySubpage();
  }

  // ---------------------------------------------------------------------------
  // Overlays
  // ---------------------------------------------------------------------------

  Future<void> _changePersona() async {
    final AiPersona? result = await AiPersonaDialog.show(
      context,
      current: _repo.persona,
    );
    if (result != null && result != _repo.persona) {
      _repo.setPersona(result);
    }
  }

  Future<void> _openCreateSheet(AiCreateTarget target, {AiChartSetup? setup}) async {
    await AiCreateSheet.show(
      context,
      repository: _repo,
      target: target,
      setup: setup,
      onOpenRef: widget.onOpenRef,
    );
  }

  Future<void> _openChartAnalysis(AiChartSetup setup) async {
    await AiChartAnalysisDialog.show(
      context,
      repository: _repo,
      setup: setup,
      onOpenRef: widget.onOpenRef,
    );
  }

  void _handleCreateFromChat(AiSuggestedAction action) {
    if (action.target == AiCreateTarget.chartAnalysis) {
      final AiChartSetup? setup =
          action.setupId != null ? _repo.setupById(action.setupId!) : null;
      if (setup != null) {
        _openChartAnalysis(setup);
      } else {
        // Fallback: use the first chart setup
        final List<AiChartSetup> setups = _repo.chartSetups;
        if (setups.isNotEmpty) _openChartAnalysis(setups.first);
      }
    } else {
      _openCreateSheet(action.target);
    }
  }

  void _handleCreateTarget(AiCreateTarget target) {
    if (target == AiCreateTarget.chartAnalysis) {
      final List<AiChartSetup> setups = _repo.chartSetups;
      if (setups.isNotEmpty) {
        _openChartAnalysis(setups.first);
      }
    } else {
      _openCreateSheet(target);
    }
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return AiDensityScope(
      child: Builder(
        builder: (BuildContext context) {
          final UiResponsive res = context.uiRes;
          if (res.isMobile) return _buildMobile(context);
          if (res.isDesktop) return _buildDesktop(context);
          return _buildTablet(context);
        },
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Mobile: tabbed (Chat / Insights / Create) + pushable history panel
  // ---------------------------------------------------------------------------

  Widget _buildMobile(BuildContext context) {
    if (_mobilePanel == _MobilePanel.history) {
      return _historyPanel(context);
    }
    return Column(
      children: <Widget>[
        Expanded(child: _mobileTabContent(context)),
        _mobileTabBar(context),
      ],
    );
  }

  Widget _mobileTabContent(BuildContext context) {
    return switch (_mobileTab) {
      0 => _chatView(context, showHeader: true),
      1 => _insightsView(context),
      2 => _createView(context),
      _ => _chatView(context, showHeader: true),
    };
  }

  Widget _mobileTabBar(BuildContext context) {
    final UiTheme theme = context.ui;
    final UiColors colors = theme.colors;
    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(
          top: BorderSide(color: colors.border, width: theme.borders.hairline),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: context.sp(theme.spacing.md),
            vertical: context.sp(theme.spacing.xs),
          ),
          child: UiToggleGroup<int>(
            value: _mobileTab,
            onChanged: (int tab) => setState(() => _mobileTab = tab),
            options: <UiOption<int>>[
              UiOption<int>(label: 'Chat', value: 0, icon: Icons.chat_outlined),
              UiOption<int>(label: 'Insights', value: 1, icon: Icons.insights_outlined),
              UiOption<int>(label: 'Create', value: 2, icon: Icons.add_circle_outline),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Tablet: thread rail + chat
  // ---------------------------------------------------------------------------

  Widget _buildTablet(BuildContext context) {
    final UiTheme theme = context.ui;
    final UiColors colors = theme.colors;
    final double railWidth = context.sz(300);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        SizedBox(
          width: railWidth,
          child: DecoratedBox(
            decoration: BoxDecoration(
              border: Border(
                right: BorderSide(color: colors.border, width: theme.borders.hairline),
              ),
            ),
            child: _historyRail(context),
          ),
        ),
        Expanded(
          child: DefaultTabController(
            length: 3,
            child: Column(
              children: <Widget>[
                Container(
                  decoration: BoxDecoration(
                    color: theme.colors.surface,
                    border: Border(
                      bottom: BorderSide(
                        color: theme.colors.border,
                        width: theme.borders.hairline,
                      ),
                    ),
                  ),
                  child: TabBar(
                    labelStyle: context.uiText.bodyStrong.copyWith(
                      fontSize: context.fs(12.5),
                    ),
                    unselectedLabelStyle: context.uiText.caption,
                    indicatorColor: theme.colors.primary,
                    labelColor: theme.colors.foreground,
                    unselectedLabelColor: theme.colors.foregroundMuted,
                    tabs: const <Widget>[
                      Tab(text: 'Chat'),
                      Tab(text: 'Insights'),
                      Tab(text: 'Create'),
                    ],
                  ),
                ),
                Expanded(
                  child: TabBarView(
                    children: <Widget>[
                      _chatView(context, showHeader: true),
                      _insightsView(context),
                      _createView(context),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Desktop: thread rail + chat + insights side panel
  // ---------------------------------------------------------------------------

  Widget _buildDesktop(BuildContext context) {
    final UiTheme theme = context.ui;
    final UiColors colors = theme.colors;
    final double railWidth = context.sz(280);
    final double insightsWidth = context.sz(340);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        SizedBox(
          width: railWidth,
          child: DecoratedBox(
            decoration: BoxDecoration(
              border: Border(
                right: BorderSide(color: colors.border, width: theme.borders.hairline),
              ),
            ),
            child: _historyRail(context),
          ),
        ),
        Expanded(child: _chatView(context, showHeader: true)),
        SizedBox(
          width: insightsWidth,
          child: DecoratedBox(
            decoration: BoxDecoration(
              border: Border(
                left: BorderSide(color: colors.border, width: theme.borders.hairline),
              ),
            ),
            child: _desktopSidePanel(context),
          ),
        ),
      ],
    );
  }

  /// Desktop right side-panel with tabs for Insights and Create.
  Widget _desktopSidePanel(BuildContext context) {
    final UiTheme theme = context.ui;
    return DefaultTabController(
      length: 2,
      child: Column(
        children: <Widget>[
          Container(
            decoration: BoxDecoration(
              color: theme.colors.surface,
              border: Border(
                bottom: BorderSide(
                  color: theme.colors.border,
                  width: theme.borders.hairline,
                ),
              ),
            ),
            child: TabBar(
              labelStyle: context.uiText.bodyStrong.copyWith(
                fontSize: context.fs(12.5),
              ),
              unselectedLabelStyle: context.uiText.caption,
              indicatorColor: theme.colors.primary,
              labelColor: theme.colors.foreground,
              unselectedLabelColor: theme.colors.foregroundMuted,
              tabs: const <Widget>[
                Tab(text: 'Insights'),
                Tab(text: 'Create'),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              children: <Widget>[
                _insightsView(context),
                _createView(context),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Shared panes
  // ---------------------------------------------------------------------------

  Widget _chatView(BuildContext context, {bool showHeader = false}) {
    return AiChatView(
      repository: _repo,
      onCreateFromChat: _handleCreateFromChat,
      onOpenRef: widget.onOpenRef ?? (_) {},
      onOpenPersona: _changePersona,
      onOpenHistory: _isMobile ? _openHistory : null,
    );
  }

  Widget _insightsView(BuildContext context) {
    return AiInsightsView(
      repository: _repo,
      onOpenChartAnalysis: _openChartAnalysis,
      onCreateFromSetup: (AiChartSetup setup, AiCreateTarget target) {
        _openCreateSheet(target, setup: setup);
      },
      onAskPrompt: (String prompt) =>
          _handleCreateTargetWithPrompt(null, prompt: prompt),
    );
  }

  Widget _createView(BuildContext context) {
    return AiCreateView(
      repository: _repo,
      onCreateTarget: _handleCreateTargetWithPrompt,
    );
  }

  void _handleCreateTargetWithPrompt(AiCreateTarget? target, {String? prompt}) {
    if (target != null) {
      _handleCreateTarget(target);
    } else if (prompt != null) {
      _repo.sendPrompt(prompt);
      if (_isMobile) setState(() => _mobileTab = 0);
    }
  }

  Widget _historyRail(BuildContext context) {
    return AiHistoryView(
      repository: _repo,
      selectedThreadId: _repo.activeThreadId,
      onSelectThread: _selectThread,
      onNewThread: () => _repo.newThread(),
      searchQuery: _searchQuery,
    );
  }

  Widget _historyPanel(BuildContext context) {
    return Column(
      children: <Widget>[
        if (!widget.embedInScaffold)
          _panelHeader(context, 'Conversation history'),
        Expanded(
          child: AiHistoryView(
            repository: _repo,
            selectedThreadId: _repo.activeThreadId,
            searchQuery: _searchQuery,
            onSelectThread: (String id) {
              _selectThread(id);
              _closePanel();
            },
            onNewThread: () {
              _repo.newThread();
              _closePanel();
            },
          ),
        ),
      ],
    );
  }

  Widget _panelHeader(BuildContext context, String title) {
    final UiTheme theme = context.ui;
    final UiColors colors = theme.colors;
    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(
          bottom: BorderSide(color: colors.border, width: theme.borders.hairline),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: context.sp(theme.spacing.xs),
            vertical: context.sp(theme.spacing.xs),
          ),
          child: Row(
            children: <Widget>[
              UiIconButton(
                icon: Icons.arrow_back_rounded,
                tooltip: 'Back',
                size: UiSize.sm,
                onPressed: _closePanel,
              ),
              SizedBox(width: context.sp(theme.spacing.xxs)),
              Expanded(
                child: Text(title, style: context.uiText.bodyStrong),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

enum _MobilePanel { none, history }
