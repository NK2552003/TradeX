import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:alphajournal/core/app-ui/app_ui.dart';
import 'package:alphajournal/core/config/customer_limitations.dart';
// ignore: unnecessary_import
import 'package:alphajournal/core/flutter-ui/flutter_ui.dart';
import 'package:alphajournal/core/linking/link_graph.dart';
import 'package:alphajournal/core/navigation/feature_location_scope.dart';
import 'package:alphajournal/features/auth/models/auth_user_role.dart';

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
    this.onOpenSettings,
    this.searchQuery,
    this.openRequest,
    this.embedInScaffold = true,
    this.initialPrompt,
    this.autoSendInitialPrompt = false,
    this.contextCard,
  });
  final CopilotController? repository;
  final UserRole userRole;
  final AppTrader? currentUser;
  final void Function(String? title, IconData? icon, VoidCallback? onBack)?
  onSubpageChanged;
  final ValueChanged<AppLinkRef>? onOpenRef;
  final VoidCallback? onOpenSettings;
  final String? searchQuery;
  final AppLinkOpenRequest? openRequest;
  final bool embedInScaffold;
  final String? initialPrompt;
  final bool autoSendInitialPrompt;
  final Widget? contextCard;
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

  Future<void> _copyThread() async {
    final thread = _controller.activeThread;
    if (thread == null || thread.messages.isEmpty) return;
    final buffer = StringBuffer('# ${thread.title}\n\n');
    for (final msg in thread.messages) {
      if (msg.body.trim().isEmpty) continue;
      buffer.writeln(msg.isUser ? '## Question' : '## Answer');
      buffer.writeln(msg.body.trim());
      if (!msg.isUser && msg.sources.isNotEmpty) {
        buffer.writeln('\n### Sources');
        for (var i = 0; i < msg.sources.length; i++) {
          final src = msg.sources[i];
          final url = textOf(src, 'url');
          if (url.isEmpty) continue;
          final title = textOf(src, 'title', textOf(src, 'domain', url));
          buffer.writeln('${i + 1}. [$title]($url)');
        }
      }
      buffer.writeln();
    }
    await Clipboard.setData(ClipboardData(text: buffer.toString().trim()));
    if (mounted) {
      UiToast.success(context, title: 'Research thread copied as Markdown');
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_accountChanged);
    _voice.dispose();
    if (widget.repository == null) _controller.dispose();
    super.dispose();
  }

  String? _cachedAppearance;
  UiTheme? _cachedUiTheme;
  ThemeData? _cachedThemeData;
  UiTheme? _cachedParentTheme;

  @override
  Widget build(BuildContext context) {
    final parentTheme = context.ui;
    return AnimatedBuilder(
      animation: Listenable.merge([_controller, _voice]),
      builder: (context, _) {
        final appearance = textOf(
          _controller.workspace.settings,
          'appearance',
          'system',
        );
        if (_cachedThemeData == null ||
            _cachedAppearance != appearance ||
            (appearance == 'system' && _cachedParentTheme != parentTheme)) {
          final theme = switch (appearance) {
            'light' => UiTheme.light(),
            'dark' => UiTheme.dark(),
            _ => parentTheme,
          };
          _cachedAppearance = appearance;
          _cachedParentTheme = parentTheme;
          _cachedUiTheme = theme;
          _cachedThemeData = theme.toThemeData();
        }
        return UiThemeScope(
          theme: _cachedUiTheme!,
          child: Theme(
            data: _cachedThemeData!,
            child: Material(
              type: MaterialType.transparency,
              child: Builder(builder: _buildWorkspace),
            ),
          ),
        );
      },
    );
  }

  Widget _buildWorkspace(BuildContext context) {
    final theme = context.ui;
    final device = context.uiRes;
    final double horizPad = context.sp(
      device.pick<double>(
        mobile: theme.spacing.sm,
        tablet: theme.spacing.md,
        desktop: theme.spacing.lg,
      ),
    );
    final double topBarPad = context.sp(
      device.isMobile ? theme.spacing.sm : theme.spacing.md,
    );
    final double bottomPad = context.sp(
      device.isMobile ? theme.spacing.sm : theme.spacing.md,
    );
    final bool showInnerHeader = widget.embedInScaffold;
    final bool hasVoiceTop =
        _voice.active || _voice.connecting || _voice.error != null;
    final double headerClearance = showInnerHeader
        ? topBarPad +
              context.sz(36) +
              (device.isTablet
                  ? context.sp(theme.spacing.sm) + context.sz(40)
                  : 0) +
              context.sp(theme.spacing.sm)
        : topBarPad + context.sz(34);

    final chat = Padding(
      padding: EdgeInsets.only(bottom: bottomPad),
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: context.sz(760)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (hasVoiceTop || widget.contextCard != null)
                SizedBox(height: headerClearance),
              if (widget.contextCard != null) ...[
                widget.contextCard!,
                UiGap.v(theme.spacing.sm),
              ],
              if (_voice.active || _voice.connecting) ...[
                CopilotVoicePanel(
                  voice: _voice,
                  name: _controller.specialist?.name ?? 'Copilot',
                ),
                UiGap.v(theme.spacing.md),
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
                  voiceActive: _voice.active,
                  topInset: (hasVoiceTop || widget.contextCard != null)
                      ? 0.0
                      : headerClearance,
                  onOpenRef: widget.onOpenRef,
                  onVoice: _voice.active
                      ? _voice.end
                      : (!_controller.isAiQuotaBlocked &&
                                !CustomerLimitations.isAiQuotaExhausted() &&
                                !_voice.connecting &&
                                !_controller.conversationLocked
                            ? _voice.start
                            : null),
                  onSpeakMessage: _voice.speakAssistantMessage,
                  onPage: (page) {
                    setState(() => _page = page);
                    _showWorkspace(true);
                  },
                  initialPrompt: _allowInitialPrompt
                      ? widget.initialPrompt
                      : null,
                  autoSendInitialPrompt:
                      _allowInitialPrompt && widget.autoSendInitialPrompt,
                ),
              ),
            ],
          ),
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
            onOpenSettings: widget.onOpenSettings,
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
    final paddedWorkspace = Padding(
      padding: EdgeInsets.only(
        top: headerClearance,
        bottom: bottomPad,
        left: device.isDesktop ? context.sp(theme.spacing.lg) : 0,
      ),
      child: workspace,
    );

    final Widget headerOverlay = Material(
      type: MaterialType.transparency,
      child: Padding(
        padding: EdgeInsets.only(top: topBarPad),
        child: Column(
          mainAxisSize: MainAxisSize.min,
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
                  child: Text(
                    'Copilot',
                    style: context.uiText.heading,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (_controller.activeThread?.messages.any(
                      (m) => m.body.trim().isNotEmpty,
                    ) ==
                    true)
                  UiIconButton(
                    icon: Icons.ios_share_outlined,
                    tooltip: 'Copy research thread',
                    variant: UiVariant.ghost,
                    size: UiSize.sm,
                    onPressed: _copyThread,
                  ),
                if (widget.onOpenSettings != null)
                  UiIconButton(
                    icon: Icons.tune_rounded,
                    tooltip: 'AI & Copilot settings',
                    variant: UiVariant.ghost,
                    size: UiSize.sm,
                    onPressed: widget.onOpenSettings,
                  ),
                if (!device.isTablet)
                  UiIconButton(
                    icon: Icons.space_dashboard_outlined,
                    tooltip: device.isMobile ? 'Library' : 'Workspace',
                    variant: _workspaceOpen ? UiVariant.soft : UiVariant.ghost,
                    size: UiSize.sm,
                    onPressed: () => _showWorkspace(!_workspaceOpen),
                  ),
              ],
            ),
            if (device.isTablet) ...[
              UiGap.v(theme.spacing.xs),
              UiTabs(
                tabs: const ['Conversation', 'Workspace'],
                selectedIndex: _workspaceOpen ? 1 : 0,
                onChanged: (index) => _showWorkspace(index == 1),
              ),
            ],
          ],
        ),
      ),
    );

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: horizPad),
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: context.sz(1600)),
            child: Stack(
              children: [
                Positioned.fill(
                  child: device.isDesktop
                      ? UiSplitPane(
                          primary: chat,
                          detail: paddedWorkspace,
                          initialRatio: .62,
                          minRatio: .5,
                          maxRatio: .75,
                          showDetail: _workspaceOpen,
                          splitFrom: UiDeviceType.desktop,
                        )
                      : IndexedStack(
                          index: _workspaceOpen ? 1 : 0,
                          children: [chat, paddedWorkspace],
                        ),
                ),
                if (showInnerHeader)
                  Positioned(top: 0, left: 0, right: 0, child: headerOverlay)
                else
                  Positioned(
                    top: topBarPad,
                    left: 0,
                    right: 0,
                    child: Material(
                      type: MaterialType.transparency,
                      child: Row(
                        children: <Widget>[
                          if (_workspaceOpen)
                            UiIconButton(
                              icon: Icons.arrow_back,
                              tooltip: 'Back to conversation',
                              variant: UiVariant.ghost,
                              size: UiSize.sm,
                              onPressed: () => _showWorkspace(false),
                            ),
                          const Spacer(),
                          if (_controller.activeThread?.messages.any(
                                (m) => m.body.trim().isNotEmpty,
                              ) ==
                              true)
                            UiIconButton(
                              icon: Icons.ios_share_outlined,
                              tooltip: 'Copy research thread',
                              variant: UiVariant.ghost,
                              size: UiSize.sm,
                              onPressed: _copyThread,
                            ),
                          UiIconButton(
                            icon: Icons.history_rounded,
                            tooltip: device.isMobile ? 'Library' : 'Workspace',
                            variant: _workspaceOpen
                                ? UiVariant.soft
                                : UiVariant.ghost,
                            size: UiSize.sm,
                            onPressed: () => _showWorkspace(!_workspaceOpen),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
