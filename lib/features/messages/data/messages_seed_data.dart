import 'dart:math';

import 'package:alphajournal/core/app-ui/app_ui.dart';
import 'package:alphajournal/core/data/demo_data_source.dart';
import 'package:alphajournal/features/messages/models/messages_models.dart';

/// All mock content for the Messages feature lives here — never inside widgets.
///
/// Threads and their participants are seeded from [DemoDataSource] so the same
/// people appear in the inbox, the community and the leaderboard. Message bodies,
/// attachments, shared records and reactions are defined as data below and read
/// by [MessagesRepository]; swapping in a backend means replacing these builders,
/// not touching any UI.
class MessagesSeed {
  MessagesSeed._();

  static final DemoDataSource _demo = DemoDataSource.instance;
  static final DateTime _now = DateTime.now();

  // ---------------------------------------------------------------------------
  // Threads
  // ---------------------------------------------------------------------------

  static const List<String> _previews = <String>[
    'Sent you the updated risk sheet — take a look before the open.',
    'Did you take the BANKNIFTY breakout this morning?',
    'Review notes are in the shared strategy playbook 👇',
    'Payout landed, thanks for the heads up 🙏',
    'Let us pair on the journal audit tomorrow?',
    'That gap-fade stat holds across three years of data.',
  ];

  static const List<MessagePresence> _presences = <MessagePresence>[
    MessagePresence.online,
    MessagePresence.busy,
    MessagePresence.away,
    MessagePresence.offline,
    MessagePresence.online,
    MessagePresence.offline,
  ];

  /// Direct + group threads for the primary inbox.
  static List<MessageThread> threads() {
    final List<AppTrader> peers = _demo.traders();
    final List<MessageThread> threads = <MessageThread>[
      for (int i = 0; i < peers.length && i < 6; i++)
        MessageThread(
          id: 'thread_${i + 1}',
          peer: peers[i],
          presence: _presences[i % _presences.length],
          lastMessagePreview: _previews[i % _previews.length],
          lastMessageAt: _now.subtract(Duration(minutes: 4 + i * 137)),
          unread: i == 0
              ? 3
              : i == 1
              ? 1
              : 0,
          pinned: i == 0,
          muted: i == 3,
          lastFromMe: i.isOdd,
          lastStatus: i == 1 ? MessageStatus.delivered : MessageStatus.read,
        ),
    ];

    // One group thread so the "Groups" filter and multi-avatar rendering are
    // exercised without a bespoke data shape.
    threads.insert(
      2,
      MessageThread(
        id: 'thread_group_momentum',
        peer: peers[1],
        participants: peers.take(4).toList(),
        isGroup: true,
        groupTitle: 'Momentum Squad',
        presence: MessagePresence.online,
        lastMessagePreview:
            '${peers[2].displayName ?? peers[2].handle}: '
            'Watching NIFTY for a range expansion.',
        lastMessageAt: _now.subtract(const Duration(minutes: 22)),
        unread: 5,
        lastFromMe: false,
      ),
    );

    return threads;
  }

  /// Inbound message requests from people the trader has not replied to yet.
  static List<MessageThread> requests() {
    final List<AppTrader> peers = _demo.traders();
    return <MessageThread>[
      for (int i = 6; i < peers.length && i < 9; i++)
        MessageThread(
          id: 'request_${i + 1}',
          peer: peers[i],
          presence: _presences[i % _presences.length],
          lastMessagePreview: const <String>[
            'Hey! Loved your breakdown on the earnings drift setup.',
            'Would love to swap journals — are you open to it?',
            'Following your calls for a while. Mind if I ask about sizing?',
          ][(i - 6) % 3],
          lastMessageAt: _now.subtract(Duration(hours: 2 + (i - 6) * 9)),
          unread: 1,
          isRequest: true,
        ),
    ];
  }

  // ---------------------------------------------------------------------------
  // Messages per thread
  // ---------------------------------------------------------------------------

  static const List<String> _dialogue = <String>[
    'Morning — did you get the risk sheet I sent over?',
    'Yes, reviewing it now. The drawdown cap looks tight.',
    'It is intentional. Two red days should pause new entries.',
    'Agreed. I will mirror it in my personal rules.',
    'How did the BANKNIFTY open treat you?',
    'Clean ORB. Took partials at 1R and trailed the rest.',
    'Nice. Ping me after the close and we can compare journals.',
    'Will do. Also want your read on the RELIANCE flag.',
  ];

  /// Full message history keyed by thread id. Attachments, a shared strategy
  /// card and reactions are sprinkled in so every bubble variant is covered.
  static Map<String, List<ChatMessage>> messagesByThread() {
    final Map<String, List<ChatMessage>> out = <String, List<ChatMessage>>{};
    final List<MessageThread> all = <MessageThread>[
      ...threads(),
      ...requests(),
    ];

    for (final MessageThread thread in all) {
      final Random rng = Random(thread.id.hashCode & 0x7fffffff);
      final int count = thread.isRequest ? 1 : 5 + rng.nextInt(4);
      final List<ChatMessage> msgs = <ChatMessage>[];

      for (int i = 0; i < count; i++) {
        final bool fromMe = thread.isRequest ? false : i.isOdd;
        msgs.add(
          ChatMessage(
            id: '${thread.id}_m$i',
            threadId: thread.id,
            body: _dialogue[i % _dialogue.length],
            fromMe: fromMe,
            sentAt: _now.subtract(Duration(minutes: (count - i) * 11 + 2)),
            status: fromMe
                ? (i >= count - 2
                      ? MessageStatus.delivered
                      : MessageStatus.read)
                : MessageStatus.read,
            reactions: i == 1
                ? const <String, int>{'🔥': 2, '💯': 1}
                : const <String, int>{},
            myReactions: i == 1 ? const <String>{'🔥'} : const <String>{},
          ),
        );
      }

      // Thread-specific rich content.
      if (thread.id == 'thread_1') {
        msgs.add(
          ChatMessage(
            id: '${thread.id}_ref',
            threadId: thread.id,
            body: 'Here is the playbook we discussed.',
            fromMe: false,
            sentAt: _now.subtract(const Duration(minutes: 6)),
            sharedRef: const AppLinkRef(
              kind: AppLinkKind.strategy,
              id: 'strat_orb_reclaim',
              title: 'ORB + VWAP reclaim',
              subtitle: 'Intraday · 61% win rate',
              meta: '+2.4R avg',
            ),
          ),
        );
      } else if (thread.id == 'thread_2') {
        msgs.add(
          ChatMessage(
            id: '${thread.id}_img',
            threadId: thread.id,
            body: '',
            fromMe: true,
            sentAt: _now.subtract(const Duration(minutes: 9)),
            status: MessageStatus.read,
            attachment: const MessageAttachment(
              id: 'att_chart_1',
              kind: MessageAttachmentKind.chart,
              title: 'BANKNIFTY 15m',
              subtitle: 'Opening range breakout',
              thumbnailUrl: 'https://picsum.photos/seed/bnf15m/480/300',
            ),
          ),
        );
        msgs.add(
          ChatMessage(
            id: '${thread.id}_setup',
            threadId: thread.id,
            body: 'Setup if it reclaims the range high:',
            fromMe: true,
            sentAt: _now.subtract(const Duration(minutes: 8)),
            status: MessageStatus.read,
            attachment: const MessageAttachment(
              id: 'att_setup_1',
              kind: MessageAttachmentKind.tradeSetup,
              title: 'BANKNIFTY long',
              subtitle: 'ORB reclaim · 15m close',
              direction: 'long',
              entry: 48250,
              stop: 48050,
              target: 48750,
            ),
          ),
        );
      } else if (thread.id == 'thread_group_momentum') {
        msgs.add(
          ChatMessage(
            id: '${thread.id}_ref',
            threadId: thread.id,
            body: 'Dropping the shared journal entry from today.',
            fromMe: false,
            sentAt: _now.subtract(const Duration(minutes: 14)),
            sharedRef: const AppLinkRef(
              kind: AppLinkKind.journal,
              id: 'trade_bnf_orb',
              title: 'BANKNIFTY ORB long',
              subtitle: 'Closed · +1.9R',
              meta: '+₹18,400',
            ),
          ),
        );
      }

      msgs.sort((ChatMessage a, ChatMessage b) => a.sentAt.compareTo(b.sentAt));
      out[thread.id] = msgs;
    }
    return out;
  }

  // ---------------------------------------------------------------------------
  // Composer quick-share suggestions
  // ---------------------------------------------------------------------------

  /// Records the trader can share into a conversation from the composer.
  static List<AppLinkRef> shareableRefs() => const <AppLinkRef>[
    AppLinkRef(
      kind: AppLinkKind.strategy,
      id: 'strat_orb_reclaim',
      title: 'ORB + VWAP reclaim',
      subtitle: 'Intraday playbook',
      meta: '61% win',
    ),
    AppLinkRef(
      kind: AppLinkKind.journal,
      id: 'trade_bnf_orb',
      title: 'BANKNIFTY ORB long',
      subtitle: 'Closed today',
      meta: '+1.9R',
    ),
    AppLinkRef(
      kind: AppLinkKind.note,
      id: 'note_pretrade_checklist',
      title: 'Pre-trade checklist',
      subtitle: 'Updated this week',
    ),
    AppLinkRef(
      kind: AppLinkKind.ticker,
      id: 'RELIANCE',
      title: 'RELIANCE',
      subtitle: 'NSE · Equity',
    ),
  ];

  /// Emoji offered in the quick-reaction row.
  static const List<String> quickReactions = <String>[
    '👍',
    '🔥',
    '💯',
    '😂',
    '😮',
    '🙏',
  ];
}
