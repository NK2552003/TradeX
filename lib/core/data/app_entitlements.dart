import 'package:alphajournal/core/app-ui/app_ui.dart';

/// Paid capabilities that must be enforced before a feature is mounted.
///
/// Keeping this policy outside presentation code ensures navigation, deep
/// links, repositories, and plan copy all use the same tier boundary.
enum AppEntitlement {
  marketIntelligence(
    minimumTier: AppTier.premium,
    title: 'Market Intelligence',
    reason:
        'Full Market Intelligence is included with AlphaJournal Basic and Pro. Free includes only the limited market previews shown in Community.',
  ),
  messages(
    minimumTier: AppTier.premium,
    title: 'Messages',
    reason: 'Private Messages are included with AlphaJournal Basic and Pro.',
  ),
  advancedCalculators(
    minimumTier: AppTier.premium,
    title: 'Advanced calculators',
    reason:
        'Advanced trading, options, forex, and tax calculators are included with AlphaJournal Basic and Pro. Core calculators remain available on Free.',
  );

  const AppEntitlement({
    required this.minimumTier,
    required this.title,
    required this.reason,
  });

  final AppTier minimumTier;
  final String title;
  final String reason;

  bool allows(AppTier tier) => tier.index >= minimumTier.index;

  static AppEntitlement? forDestination(String destination) {
    if (destination == 'messages') return AppEntitlement.messages;
    if (destination == 'market' || destination.startsWith('market_')) {
      return AppEntitlement.marketIntelligence;
    }
    return null;
  }

  static const Set<String> advancedCalculatorIds = <String>{
    'margin',
    'pivot_points',
    'fibonacci',
    'options_pnl',
    'black_scholes',
    'currency',
    'pip_value',
    'turnover',
  };

  static bool calculatorAllowed(String calculatorId, AppTier tier) =>
      !advancedCalculatorIds.contains(calculatorId) ||
      AppEntitlement.advancedCalculators.allows(tier);
}
