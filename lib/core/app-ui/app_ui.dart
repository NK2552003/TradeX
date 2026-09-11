/// app-ui — domain layer built on top of `flutter-ui`.
///
/// Single import surface:
///   import 'package:your_app/app-ui/app_ui.dart';
library;

export '../flutter-ui/flutter_ui.dart';

// Foundations
export 'theme/app_tokens.dart';
export 'theme/app_theme_controller.dart';
export 'motion/app_motion.dart';
export 'motion/page_transition.dart';
export 'models/app_models.dart';
export 'models/app_models_extra.dart';
export '../sharing/app_post_attachment.dart';
export 'brand/app_logo.dart';

// Cards
export 'cards/journal_cards.dart';
export 'cards/strategy_cards.dart';
export 'cards/portfolio_cards.dart';
export 'cards/community_cards.dart';
export 'cards/account_cards.dart';
export 'cards/ai_cards.dart';
export 'cards/notes_cards.dart';
export 'cards/calculator_cards.dart';
export 'cards/domain_cards.dart';
export 'cards/desk_record_card.dart';

// Guides
export 'guides/feature_guide.dart';
export 'guides/guide_steps.dart';

// Blocks
export 'blocks/canonical_blocks.dart';
export 'blocks/dashboard_blocks.dart';
export 'blocks/journal_blocks.dart';
export 'blocks/community_blocks.dart';
export 'blocks/account_blocks.dart';
export 'blocks/ai_blocks.dart';
export 'blocks/chart_blocks.dart';
export 'blocks/search_blocks.dart';
export 'blocks/enterprise_blocks.dart';
export 'blocks/notes_blocks.dart';
export 'blocks/calculator_blocks.dart';
export 'blocks/workbench_blocks.dart';
export 'blocks/research_blocks.dart';
export 'blocks/desk_blocks.dart';
export 'blocks/linking_blocks.dart';
export 'blocks/journal_note_blocks.dart';
export 'blocks/strategy_note_blocks.dart';

// Shell
export 'shell/app_shell.dart';
export 'shell/app_workspace.dart';
