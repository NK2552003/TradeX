/// app-ui — domain layer built on top of `flutter-ui`.
///
/// Single import surface:
///   import 'package:your_app/app-ui/app_ui.dart';
library;

export '../flutter-ui/flutter_ui.dart';

// Foundations
export 'theme/app_tokens.dart';
export 'motion/app_motion.dart';
export 'models/app_models.dart';
export 'models/app_models_extra.dart';
export 'brand/app_logo.dart';

// Cards
export 'cards/journal_cards.dart';
export 'cards/strategy_cards.dart';
export 'cards/watchlist_cards.dart';
export 'cards/portfolio_cards.dart';
export 'cards/community_cards.dart';
export 'cards/account_cards.dart';
export 'cards/ai_cards.dart';

// Blocks
export 'blocks/dashboard_blocks.dart';
export 'blocks/journal_blocks.dart';
export 'blocks/market_blocks.dart' hide AppAiInsightsBlock;
export 'blocks/community_blocks.dart';
export 'blocks/account_blocks.dart';
export 'blocks/ai_blocks.dart';
export 'blocks/chart_blocks.dart';
export 'blocks/search_blocks.dart';
export 'blocks/enterprise_blocks.dart';

// Shell
export 'shell/app_shell.dart';
export 'shell/app_workspace.dart';
