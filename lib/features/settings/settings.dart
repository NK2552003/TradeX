/// Settings feature for TraderHub TradeX
library;

// Models
export 'models/notification_prefs_model.dart';
export 'models/privacy_settings_model.dart';
export 'models/trading_prefs_model.dart';
export 'models/org_models.dart';
export 'models/billing_models.dart';
export 'models/connected_account_model.dart';
export 'models/affiliate_settings_model.dart';
export 'models/desk_risk_model.dart';

// Repositories
export 'data/repositories/profile_settings_repository.dart';
export 'data/repositories/notification_prefs_repository.dart';
export 'data/repositories/privacy_repository.dart';
export 'data/repositories/trading_prefs_repository.dart';
export 'data/repositories/billing_settings_repository.dart';
export 'data/repositories/organization_settings_repository.dart';
export 'data/repositories/affiliate_settings_repository.dart';
export 'data/repositories/desk_risk_repository.dart';

// Widgets
export 'presentation/widgets/settings_nav_row.dart';

// Shared Pages
export 'presentation/pages/shared/settings_root_page.dart';
export 'presentation/pages/shared/profile_settings_page.dart';
export 'presentation/pages/shared/account_security_page.dart';
export 'presentation/pages/shared/delete_account_page.dart';
export 'presentation/pages/shared/notifications_settings_page.dart';
export 'presentation/pages/shared/privacy_settings_page.dart';
export 'presentation/pages/shared/blocked_users_page.dart';
export 'presentation/pages/shared/appearance_settings_page.dart';
export 'presentation/pages/shared/help_about_page.dart';

// Trader Pages
export 'presentation/pages/trader/trading_preferences_page.dart';
export 'presentation/pages/trader/trader_affiliate_perks_page.dart';
export 'presentation/pages/trader/billing_settings_page.dart';
export 'presentation/pages/trader/change_plan_page.dart';
export 'presentation/pages/trader/billing_history_page.dart';
export 'presentation/pages/trader/invoice_detail_page.dart';

// Affiliate Pages
export 'presentation/pages/affiliate/affiliate_settings_page.dart';

// Admin / Institutional Desk Pages
export 'presentation/pages/admin/organization_settings_page.dart';
export 'presentation/pages/admin/team_roles_page.dart';
export 'presentation/pages/admin/desk_risk_page.dart';
