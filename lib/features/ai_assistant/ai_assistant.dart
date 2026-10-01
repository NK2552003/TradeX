/// AI Assistant feature — conversational copilot for trade analysis,
/// journal/note/strategy/post generation, and market insights.
///
/// Public surface: the responsive [AiAssistantRootScreen] (mounted by the app
/// shell), the [AiAssistantRepository] (inject-or-own `ChangeNotifier`), the
/// domain models, and the overlays that trigger the "create anything" flow.
library;

export 'data/ai_assistant_repository.dart';
export 'models/ai_assistant_models.dart';
export 'presentation/ai_assistant_root_screen.dart';
export 'presentation/overlays/ai_assistant_overlay_sheet.dart';
export 'presentation/overlays/ai_chart_analysis_dialog.dart';
export 'presentation/overlays/ai_create_sheet.dart';
export 'presentation/overlays/ai_persona_dialog.dart';
export 'presentation/views/ai_chat_view.dart';
export 'presentation/views/ai_create_view.dart';
export 'presentation/views/ai_history_view.dart';
export 'presentation/views/ai_insights_view.dart';
export 'presentation/widgets/ai_assistant_widgets.dart';
