import 'package:tradex/core/linking/link_graph.dart';
import 'package:flutter/material.dart';
import 'package:tradex/core/app-ui/app_ui.dart';
import 'package:tradex/features/community/data/community_repository.dart';
import 'package:tradex/core/data/demo_data_source.dart';
import 'package:tradex/features/auth/models/auth_user_role.dart';
import 'package:tradex/features/messages/data/messages_repository.dart';
import 'package:tradex/features/messages/models/messages_models.dart';
import 'package:tradex/features/messages/presentation/overlays/conversation_info_sheet.dart';

import 'package:tradex/features/messages/presentation/overlays/new_message_dialog.dart';
import 'package:tradex/features/messages/presentation/views/messages_archived_view.dart';
import 'package:tradex/features/messages/presentation/views/messages_inbox_view.dart';
import 'package:tradex/features/messages/presentation/views/messages_requests_view.dart';
import 'package:tradex/features/messages/presentation/views/messages_thread_view.dart';
import 'package:tradex/features/messages/presentation/widgets/messages_widgets.dart';
import 'package:tradex/features/settings/presentation/pages/shared/trader_profile_preview_page.dart';

/// The Messages shell — three-tier responsive direct-messaging layout.
///
/// **Mobile** (< 600 px):
///   - Push navigation: the inbox fills the screen; opening a thread replaces it
///     with the full-screen conversation and announces a back handler via
///     [onSubpageChanged].
///
/// **Tablet** (600–904 px) and **Desktop** (≥ 905 px):
///   - Persistent split pane: the inbox list on the left, the open conversation
///     on the right. Desktop widens the inbox rail and centres the chat column.
///
/// All content is served by [MessagesRepository]; this widget owns only
/// navigation and which secondary view (requests / archive) is showing.
class MessagesRootScreen extends StatefulWidget {
  const MessagesRootScreen({
    super.key,
    this.userRole = UserRole.customer,
    this.currentUser,
    this.onSubpageChanged,
    this.onOpenRef,
    this.repository,
    this.communityRepository,
    this.searchQuery,
    this.openRequest,
    this.embedInScaffold = true,
  });

  final UserRole userRole;
  final AppTrader? currentUser;
  final void Function(String? title, IconData? icon, VoidCallback? onBack)?
      onSubpageChanged;

  /// Opens a shared Writing-Desk record in its home feature. Supplied by shell.
  final void Function(AppLinkRef ref)? onOpenRef;

  /// Optional shared repository; an internal one is created if omitted.
  final MessagesRepository? repository;
  final CommunityRepository? communityRepository;

  /// Search text pushed from the global top header.
  final String? searchQuery;

  /// True when embedded inside AppShell (avoids duplicate chrome on mobile).
  final bool embedInScaffold;

  /// Link request to open a specific thread.
  final AppLinkOpenRequest? openRequest;

  @override
  State<MessagesRootScreen> createState() => MessagesRootScreenState();
}

class MessagesRootScreenState extends State<MessagesRootScreen> {
  late final MessagesRepository _repo;
  late final bool _ownsRepo;

  /// Which conversation is open in the detail pane (tablet/desktop) or pushed
  /// full-screen (mobile). Null on tablet/desktop shows the empty detail state.
  String? _activeThreadId;

  /// Secondary panel currently in the mobile navigation stack.
  _Secondary _secondary = _Secondary.none;
  _Secondary? _returnSecondary;

  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _ownsRepo = widget.repository == null;
    _repo = widget.repository ?? MessagesRepository();
    _searchQuery = widget.searchQuery ?? '';
    _repo.addListener(_onRepo);
    
    if (widget.openRequest != null) {
      _applyRequest(widget.openRequest!);
    }
  }

  @override
  void didUpdateWidget(covariant MessagesRootScreen oldWidget) {
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
    if (!_isMobile) {
      widget.onSubpageChanged?.call(null, null, null);
      return;
    }
    if (_secondary != _Secondary.none) {
      final String title = switch (_secondary) {
        _Secondary.requests => 'Message requests',
        _Secondary.archived => 'Archived',
        _Secondary.none => '',
      };
      widget.onSubpageChanged?.call(title, null, _closeSecondary);
      return;
    }
    if (_activeThreadId != null) {
      final t = _repo.threadById(_activeThreadId!);
      if (t != null) {
        widget.onSubpageChanged?.call(t.title, null, _closeMobileDetail);
        return;
      }
    }
    widget.onSubpageChanged?.call(null, null, null);
  }
  
  void _applyRequest(AppLinkOpenRequest request) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      openThreadById(request.id);
    });
  }

  void _onRepo() {
    if (mounted) {
      if (_activeThreadId != null && _repo.threadById(_activeThreadId!) == null) {
        _activeThreadId = null;
      }
      setState(() {});
    }
  }

  @override
  void dispose() {
    _repo.removeListener(_onRepo);
    if (_ownsRepo) _repo.dispose();
    super.dispose();
  }

  // -------------------------------------------------------------------------
  // Public API (GlobalKey-driven from the shell)
  // -------------------------------------------------------------------------

  /// Pushes a search query in from the global header search field.
  void setSearchQuery(String query) {
    if (!mounted) return;
    setState(() => _searchQuery = query);
  }

  /// Opens a thread by its ID or associated peer trader ID.
  void openThreadById(String id) {
    final MessageThread? t = _repo.threadById(id);
    if (t != null) {
      _openThread(t);
    } else {
      for (final MessageThread th in _repo.threads) {
        if (th.peer.id == id || th.peer.handle == id) {
          _openThread(th);
          return;
        }
      }
    }
  }

  /// Opens or starts a thread with [trader].
  void openThreadWithTrader(AppTrader trader) {
    final String threadId = _repo.startConversation(trader);
    openThreadById(threadId);
  }

  // -------------------------------------------------------------------------
  // Navigation
  // -------------------------------------------------------------------------

  bool get _isMobile => context.uiRes.isMobile;

  void _openThread(MessageThread thread, {bool keepSecondaryOnWide = true}) {
    setState(() {
      _activeThreadId = thread.id;
      if (_isMobile) {
        if (_secondary != _Secondary.none) {
          _returnSecondary = _secondary;
        }
        _secondary = _Secondary.none;
      } else if (!keepSecondaryOnWide) {
        _secondary = _Secondary.none;
      }
    });
    if (_isMobile) {
      _notifySubpage();
    }
  }

  void _closeMobileDetail() {
    setState(() {
      _activeThreadId = null;
      if (_returnSecondary != null) {
        _secondary = _returnSecondary!;
        _returnSecondary = null;
        _notifySubpage();
        return;
      }
    });
    _notifySubpage();
  }

  void _openSecondary(_Secondary panel, String title) {
    setState(() {
      _secondary = panel;
      _returnSecondary = null;
    });
    if (_isMobile) {
      _notifySubpage();
    }
  }

  void _closeSecondary() {
    setState(() {
      _secondary = _Secondary.none;
      _returnSecondary = null;
    });
    _notifySubpage();
  }

  // -------------------------------------------------------------------------
  // Overlays
  // -------------------------------------------------------------------------

  Future<void> _newMessage() async {
    final List<AppTrader> candidates = DemoDataSource.instance.traders();
    await NewMessageDialog.show(
      context,
      repository: _repo,
      candidates: candidates,
      onStarted: (String threadId) {
        final MessageThread? t = _repo.threadById(threadId);
        if (t != null) _openThread(t);
      },
    );
  }

  void _openProfile(AppTrader trader) {
    final UiTheme theme = context.ui;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext ctx) {
        return ClipRRect(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(ctx.sp(theme.radii.xl)),
          ),
          child: SizedBox(
            height: MediaQuery.of(ctx).size.height * 0.88,
            child: TraderProfilePreviewPage(
              repository: widget.communityRepository,
              displayName: trader.displayName ?? trader.handle,
              handle: trader.handle,
              userRole: widget.userRole,
              avatarUrl: trader.avatarUrl,
              bio: trader.bio,
              onOpenRef: widget.onOpenRef,
              onDirectMessage: (AppTrader t) {
                Navigator.of(ctx).pop();
                final String threadId = _repo.startConversation(t);
                final MessageThread? thread = _repo.threadById(threadId);
                if (thread != null) _openThread(thread);
              },
            ),
          ),
        );
      },
    );
  }

  void _openInfo(MessageThread thread) {
    ConversationInfoSheet.show(
      context,
      repository: _repo,
      threadId: thread.id,
      onOpenRef: widget.onOpenRef,
      onOpenProfile: _openProfile,
      onLeft: () {
        if (_activeThreadId == thread.id) {
          if (_isMobile) {
            _closeMobileDetail();
          } else {
            setState(() => _activeThreadId = null);
          }
        }
      },
    );
  }

  // -------------------------------------------------------------------------
  // Build
  // -------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return MessagesDensityScope(
      child: Builder(
        builder: (BuildContext context) {
          final UiResponsive res = context.uiRes;
          if (res.isMobile) return _buildMobile(context);
          return _buildWide(context);
        },
      ),
    );
  }

  /// Mobile: a single column that swaps between inbox, an open thread, and the
  /// secondary requests/archive panels.
  Widget _buildMobile(BuildContext context) {
    if (_secondary != _Secondary.none) {
      return _secondaryView(context);
    }
    final String? id = _activeThreadId;
    if (id != null && _repo.threadById(id) != null) {
      return MessagesThreadView(
        repository: _repo,
        threadId: id,
        showHeader: true,
        showBackButton: true,
        onBack: _closeMobileDetail,
        onOpenRef: widget.onOpenRef,
        onOpenInfo: _openInfo,
        onOpenProfile: (MessageThread t) => _openProfile(t.peer),
      );
    }
    return _inbox(context);
  }

  /// Tablet + desktop: inbox rail beside the conversation detail, in a
  /// resizable [UiSplitPane] (its hairline divider separates the panes).
  Widget _buildWide(BuildContext context) {
    final Widget left = _secondary != _Secondary.none
        ? _secondaryView(context)
        : _inbox(context);

    return UiSplitPane(
      initialRatio: context.uiRes.isDesktop ? 0.3 : 0.36,
      minRatio: 0.24,
      maxRatio: 0.52,
      detailVisible: _activeThreadId != null,
      primary: left,
      detail: _detail(context),
    );
  }

  Widget _inbox(BuildContext context) {
    return MessagesInboxView(
      repository: _repo,
      selectedThreadId: _isMobile ? null : _activeThreadId,
      externalQuery: _searchQuery,
      onOpenThread: (MessageThread t) =>
          _openThread(t, keepSecondaryOnWide: false),
      onNewMessage: _newMessage,
      onOpenRequests: () =>
          _openSecondary(_Secondary.requests, 'Message requests'),
      onOpenArchived: () => _openSecondary(_Secondary.archived, 'Archived'),
      onThreadLongPress: _openInfo,
    );
  }

  Widget _detail(BuildContext context) {
    final String? id = _activeThreadId;
    if (id == null || _repo.threadById(id) == null) {
      return _emptyDetail(context);
    }
    return MessagesThreadView(
      key: ValueKey<String>(id),
      repository: _repo,
      threadId: id,
      showHeader: true,
      showBackButton: false,
      onOpenRef: widget.onOpenRef,
      onOpenInfo: _openInfo,
      onOpenProfile: (MessageThread t) => _openProfile(t.peer),
    );
  }

  Widget _emptyDetail(BuildContext context) {
    final UiTheme theme = context.ui;
    return Container(
      color: theme.colors.background,
      child: MessagesEmptyState(
        icon: Icons.forum_outlined,
        title: 'Your messages',
        message: 'Choose a conversation from the list, or start a new one.',
        action: UiButton(
          label: 'New message',
          icon: Icons.edit_square,
          onPressed: _newMessage,
        ),
      ),
    );
  }

  Widget _secondaryView(BuildContext context) {
    final Widget body = switch (_secondary) {
      _Secondary.requests => MessagesRequestsView(
          repository: _repo,
          onOpenThread: (MessageThread t) =>
              _openThread(t, keepSecondaryOnWide: true),
          onOpenProfile: _openProfile,
          onAccepted: (String threadId) {
            _closeSecondary();
            final MessageThread? t = _repo.threadById(threadId);
            if (t != null) _openThread(t, keepSecondaryOnWide: false);
          },
        ),
      _Secondary.archived => MessagesArchivedView(
          repository: _repo,
          onOpenThread: (MessageThread t) {
            _closeSecondary();
            _openThread(t, keepSecondaryOnWide: false);
          },
        ),
      _Secondary.none => const SizedBox.shrink(),
    };

    // On tablet/desktop the secondary panel replaces the inbox rail, so it needs
    // its own compact header with a back affordance.
    final String title = switch (_secondary) {
      _Secondary.requests => 'Message requests',
      _Secondary.archived => 'Archived',
      _Secondary.none => '',
    };
    return Column(
      children: <Widget>[
        AppPaneHeader(title: title, leadingBack: _closeSecondary, dense: true),
        Expanded(child: body),
      ],
    );
  }
}

enum _Secondary { none, requests, archived }
