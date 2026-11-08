import 'package:flutter/material.dart';
import 'package:tradex/core/app-ui/app_ui.dart';
// ignore: unnecessary_import
import 'package:tradex/core/flutter-ui/flutter_ui.dart';
import 'package:tradex/core/linking/link_graph.dart';
import 'package:tradex/core/navigation/feature_location_scope.dart';
import 'package:tradex/features/auth/models/auth_user_role.dart';

import '../data/copilot_controller.dart';
import '../data/voice_controller.dart';
import '../models/workspace.dart';
import 'chat_pane.dart';
import 'page_editor.dart';
import 'voice_panel.dart';
import 'workspace_pane.dart';

class CopilotScreen extends StatefulWidget {
  const CopilotScreen({
    super.key,
    this.repository,
    this.userRole = UserRole.customer,
    this.currentUser,
    this.onSubpageChanged,
    this.onOpenRef,
    this.searchQuery,
    this.openRequest,
    this.embedInScaffold = true,
    this.initialPrompt,
  });
  final CopilotController? repository;
  final UserRole userRole;
  final AppTrader? currentUser;
  final void Function(String? title, IconData? icon, VoidCallback? onBack)?
  onSubpageChanged;
  final ValueChanged<AppLinkRef>? onOpenRef;
  final String? searchQuery;
  final AppLinkOpenRequest? openRequest;
  final bool embedInScaffold;
  final String? initialPrompt;
  @override
  State<CopilotScreen> createState() => CopilotScreenState();
}

class CopilotScreenState extends State<CopilotScreen> {
  late final _controller = widget.repository ?? CopilotController();
  late final _voice = CopilotVoiceController(_controller);
  bool _workspaceOpen = false;
  WorkspacePage? _page;
  late String _query = widget.searchQuery ?? '';
  GlobalKey _chatKey = GlobalKey();
  late int _accountEpoch = _controller.accountEpoch;
  Uri? _location;
  bool _allowInitialPrompt = true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final scope = FeatureLocationScope.maybeOf(context);
    if (scope != null && scope.location != _location) {
      _location = scope.location;
      final selected = scope.selection('ai_copilot', ['chat', 'workspace']);
      if (selected != null) _workspaceOpen = selected == 1;
    }
  }

  void _showWorkspace(bool open) {
    setState(() => _workspaceOpen = open);
    FeatureLocationScope.maybeOf(
      context,
    )?.select('ai_copilot', open ? 'workspace' : 'chat');
  }

  @override
  void initState() {
    super.initState();
    _controller.addListener(_accountChanged);
    if (widget.openRequest != null) {
      _controller.selectThread(widget.openRequest!.id);
    }
  }

  void _accountChanged() {
    if (_accountEpoch == _controller.accountEpoch || !mounted) return;
    setState(() {
      _accountEpoch = _controller.accountEpoch;
      _chatKey = GlobalKey();
      _page = null;
      _query = '';
      _workspaceOpen = false;
      _allowInitialPrompt = false;
    });
  }

  @override
  void didUpdateWidget(CopilotScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.openRequest?.seq != widget.openRequest?.seq &&
        widget.openRequest != null) {
      _controller.selectThread(widget.openRequest!.id);
    }
    if (oldWidget.searchQuery != widget.searchQuery) {
      setSearchQuery(widget.searchQuery ?? '');
    }
  }

  void setSearchQuery(String value) => setState(() {
    _query = value;
    if (value.isNotEmpty) _workspaceOpen = true;
  });
  @override
  void dispose() {
    _controller.removeListener(_accountChanged);
    _voice.dispose();
    if (widget.repository == null) _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: Listenable.merge([_controller, _voice]),
    builder: (context, _) {
      final appearance = textOf(
        _controller.workspace.settings,
        'appearance',
        'system',
      );
      final theme = switch (appearance) {
        'light' => UiTheme.light(),
        'dark' => UiTheme.dark(),
        _ => context.ui,
      };
      return UiThemeScope(
        theme: theme,
        child: Theme(
          data: theme.toThemeData(),
          child: Material(
            color: theme.colors.background,
            child: Builder(builder: _buildWorkspace),
          ),
        ),
      );
    },
  );

  Widget _buildWorkspace(BuildContext context) {
    final device = context.uiRes;
    final chat = Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: context.sz(760)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_voice.active || _voice.connecting) ...[
              CopilotVoicePanel(
                voice: _voice,
                name: _controller.specialist?.name ?? 'Copilot',
              ),
              UiGap.v(context.ui.spacing.md),
            ],
            if (_voice.error != null)
              UiCallout(
                title: 'Call unavailable',
                message: _voice.error!,
                intent: UiIntent.warning,
              ),
            Expanded(
              child: CopilotChatPane(
                key: _chatKey,
                controller: _controller,
                onPage: (page) {
                  setState(() => _page = page);
                  _showWorkspace(true);
                },
                initialPrompt: _allowInitialPrompt
                    ? widget.initialPrompt
                    : null,
              ),
            ),
          ],
        ),
      ),
    );
    final workspace = _page == null
        ? CopilotWorkspacePane(
            controller: _controller,
            searchQuery: _query,
            onConversation: () => setState(() {
              if (!device.isDesktop) _workspaceOpen = false;
            }),
            onPage: (page) => setState(() => _page = page),
            onClose: () => _showWorkspace(false),
          )
        : CopilotPageEditor(
            key: ValueKey(_page!.id),
            controller: _controller,
            page: _page!,
            onClose: () => setState(() => _page = null),
            onDiscuss: (page) async {
              final candidates = _controller.workspace.specialists
                  .where((s) => s.spaceIds.contains(page.spaceId))
                  .toList();
              if (candidates.isEmpty) {
                UiToast.error(
                  context,
                  title: 'No specialist has access',
                  message: 'Grant a specialist access to this space first.',
                );
                return;
              }
              _controller.newConversation(
                specialist: candidates.first.id,
                pageId: page.id,
              );
              setState(() {
                if (!device.isDesktop) _workspaceOpen = false;
              });
            },
          );
    return UiPage(
      scrollable: false,
      maxWidth: 1600,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              if (device.isMobile && _workspaceOpen)
                UiIconButton(
                  icon: Icons.arrow_back,
                  tooltip: 'Back to conversation',
                  onPressed: () => _showWorkspace(false),
                ),
              Expanded(
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: UiDropdownMenu(
                    actions: [
                      for (final specialist
                          in _controller.workspace.specialists)
                        UiMenuItem(
                          label: specialist.name,
                          description: specialist.role,
                          enabled:
                              !_controller.conversationLocked && !_voice.active,
                          selected: specialist.id == _controller.specialist?.id,
                          onPressed: () {
                            _controller.newConversation(
                              specialist: specialist.id,
                            );
                            _showWorkspace(false);
                          },
                        ),
                    ],
                    child: ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: context.sz(180)),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Flexible(
                            child: Text(
                              _controller.specialist?.name ?? 'Copilot',
                              overflow: TextOverflow.ellipsis,
                              style: context.uiText.heading,
                            ),
                          ),
                          UiGap.h(context.ui.spacing.xs),
                          Icon(
                            Icons.keyboard_arrow_down,
                            size: context.sz(20),
                            color: context.ui.colors.foregroundMuted,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              UiIconButton(
                icon: Icons.add_comment_outlined,
                tooltip: 'New conversation',
                onPressed: _controller.conversationLocked || _voice.active
                    ? null
                    : () => _controller.newConversation(),
              ),
              UiIconButton(
                icon: Icons.call_outlined,
                tooltip: 'Start voice call',
                onPressed: !_controller.connected || _controller.voiceBusy
                    ? null
                    : _voice.start,
              ),
              if (!device.isTablet)
                UiButton(
                  label: device.isMobile ? 'Library' : 'Workspace',
                  icon: Icons.space_dashboard_outlined,
                  variant: _workspaceOpen ? UiVariant.soft : UiVariant.ghost,
                  size: UiSize.sm,
                  onPressed: () => _showWorkspace(!_workspaceOpen),
                ),
            ],
          ),
          if (device.isTablet)
            UiTabs(
              tabs: const ['Conversation', 'Workspace'],
              selectedIndex: _workspaceOpen ? 1 : 0,
              onChanged: (index) => _showWorkspace(index == 1),
            ),
          UiGap.v(context.ui.spacing.md),
          Expanded(
            child: device.isDesktop
                ? UiSplitPane(
                    primary: chat,
                    detail: Padding(
                      padding: EdgeInsets.only(
                        left: context.sp(context.ui.spacing.lg),
                      ),
                      child: workspace,
                    ),
                    initialRatio: .62,
                    minRatio: .5,
                    maxRatio: .75,
                    showDetail: _workspaceOpen,
                    splitFrom: UiDeviceType.desktop,
                  )
                : IndexedStack(
                    index: _workspaceOpen ? 1 : 0,
                    children: [chat, workspace],
                  ),
          ),
        ],
      ),
    );
  }
}
