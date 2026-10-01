/// Messages feature — direct messaging between traders.
///
/// Public surface: the responsive [MessagesRootScreen] (mounted by the app
/// shell), the [MessagesRepository] (inject-or-own `ChangeNotifier`), the
/// domain models, and the overlays that other features call to share a record
/// into a conversation ([ShareToConversationDialog]).
library;

export 'data/messages_repository.dart';
export 'models/messages_models.dart';
export 'presentation/messages_root_screen.dart';
export 'presentation/overlays/conversation_info_sheet.dart';
export 'presentation/overlays/message_actions_sheet.dart';
export 'presentation/overlays/new_message_dialog.dart';
export 'presentation/overlays/share_to_conversation_dialog.dart';
export 'presentation/views/messages_archived_view.dart';
export 'presentation/views/messages_inbox_view.dart';
export 'presentation/views/messages_requests_view.dart';
export 'presentation/views/messages_thread_view.dart';
export 'presentation/widgets/messages_widgets.dart';
