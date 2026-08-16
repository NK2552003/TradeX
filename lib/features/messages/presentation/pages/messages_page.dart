import 'package:flutter/material.dart';
import 'package:tradex/core/app-ui/app_ui.dart';

class MessagesPage extends StatefulWidget {
  const MessagesPage({super.key});

  @override
  State<MessagesPage> createState() => _MessagesPageState();
}

class _MessagesPageState extends State<MessagesPage> {
  final TextEditingController _messageController = TextEditingController();

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.ui;

    final conversations = [
      {
        'name': 'Ava Chen',
        'handle': '@quantqueen',
        'lastMessage': 'Loved your ORB strategy writeup! Are you taking \$AAPL tomorrow?',
        'time': '10:42 AM',
        'unread': true,
      },
      {
        'name': 'Marcus Vance',
        'handle': '@marcus_vance',
        'lastMessage': 'Thanks for sharing the risk calculator script.',
        'time': 'Yesterday',
        'unread': false,
      },
      {
        'name': 'Sarah Jenkins',
        'handle': '@sjenkins_fx',
        'lastMessage': 'EUR/USD bouncing off the 1.0850 support zone.',
        'time': '2 days ago',
        'unread': false,
      },
    ];

    return Padding(
      padding: EdgeInsets.all(context.sp(theme.spacing.lg)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Direct Messages',
                    style: context.uiText.display.copyWith(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: context.sp(theme.spacing.xxs)),
                  Text(
                    'One-on-one private messages with verified traders (Premium)',
                    style: context.uiText.body.copyWith(
                      color: theme.colors.foregroundMuted,
                    ),
                  ),
                ],
              ),
              const UiBadge(
                label: '1 Unread Conversation',
                intent: UiIntent.primary,
              ),
            ],
          ),
          SizedBox(height: context.sp(theme.spacing.lg)),

          // Split pane layout: Left conversation list, right active chat thread
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Conversation list
                SizedBox(
                  width: 320,
                  child: UiCard(
                    title: 'Conversations',
                    child: ListView.separated(
                      itemCount: conversations.length,
                      separatorBuilder: (context, index) => const UiDivider(),
                      itemBuilder: (context, idx) {
                        final item = conversations[idx];
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: UiAvatar(
                            name: item['name'] as String,
                          ),
                          title: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                item['name'] as String,
                                style: context.uiText.bodyStrong,
                              ),
                              Text(
                                item['time'] as String,
                                style: context.uiText.caption.copyWith(
                                  color: theme.colors.foregroundMuted,
                                ),
                              ),
                            ],
                          ),
                          subtitle: Text(
                            item['lastMessage'] as String,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: context.uiText.caption.copyWith(
                              color: (item['unread'] as bool)
                                  ? theme.colors.foreground
                                  : theme.colors.foregroundMuted,
                              fontWeight: (item['unread'] as bool)
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            ),
                          ),
                          onTap: () {},
                        );
                      },
                    ),
                  ),
                ),
                SizedBox(width: context.sp(theme.spacing.md)),

                // Active conversation thread panel
                Expanded(
                  child: UiCard(
                    title: 'Ava Chen (@quantqueen)',
                    subtitle: 'Active now • Premium Trader',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                          child: ListView(
                            children: [
                              Align(
                                alignment: Alignment.centerLeft,
                                child: Container(
                                  margin: EdgeInsets.only(bottom: context.sp(theme.spacing.sm)),
                                  padding: EdgeInsets.all(context.sp(theme.spacing.md)),
                                  decoration: BoxDecoration(
                                    color: theme.colors.surfaceHover,
                                    borderRadius: context.radius(theme.radii.md),
                                  ),
                                  child: Text(
                                    'Loved your ORB strategy writeup! Are you taking \$AAPL tomorrow?',
                                    style: context.uiText.body,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(height: context.sp(theme.spacing.md)),
                        Row(
                          children: [
                            Expanded(
                              child: UiInput(
                                value: _messageController.text,
                                hintText: 'Type your message...',
                                onChanged: (v) => _messageController.text = v,
                              ),
                            ),
                            SizedBox(width: context.sp(theme.spacing.xs)),
                            UiIconButton(
                              icon: Icons.send_rounded,
                              variant: UiVariant.primary,
                              onPressed: () {
                                if (_messageController.text.isEmpty) return;
                                UiToast.show(
                                  context,
                                  title: 'Message Sent',
                                  message: 'Message delivered to Ava Chen',
                                  intent: UiIntent.success,
                                );
                                _messageController.clear();
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
