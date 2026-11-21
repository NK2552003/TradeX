import 'package:alphajournal/core/app-ui/theme/app_tokens.dart';
import 'package:alphajournal/core/config/customer_limitations.dart';
import 'package:alphajournal/core/config/supabase_config.dart';
import 'package:alphajournal/core/data/app_session.dart';
import 'package:alphajournal/core/data/demo_data_source.dart';
import 'package:alphajournal/features/auth/models/pricing_models.dart';
import 'package:alphajournal/features/public_site/data/public_site_repository.dart';

abstract class SubscriptionPricingRepository {
  Future<PricingCatalogueResponse> getPricingCatalogue({bool annual = false});
  Future<void> selectPlan({
    required String tierId,
    required String billingCycle,
  });
}

class SubscriptionPricingRepositoryImpl
    implements SubscriptionPricingRepository {
  SubscriptionPricingRepositoryImpl({
    DemoDataSource? source,
    AppSession? session,
    PublicSiteRepository? content,
  }) : _content = content ?? publicSiteRepository(),
       _session = session ?? AppSession.instance;
  final PublicSiteRepository _content;
  final AppSession _session;
  @override
  Future<PricingCatalogueResponse> getPricingCatalogue({
    bool annual = false,
  }) async {
    final json = await _content.pricing();
    CustomerTierQuota.installPublishedCatalogue(json);
    final bool isAuthenticated =
        !SupabaseConfig.isConfigured ||
        SupabaseConfig.client?.auth.currentUser != null;
    json['plans'] = (json['plans'] as List).map((raw) {
      final row = Map<String, dynamic>.from(raw as Map);
      final currentTierName = _session.tier.value.name;
      final planTier = row['tier']?.toString();
      row['is_current'] =
          isAuthenticated &&
          (planTier == currentTierName ||
              ((planTier == 'premium' || planTier == 'pro') &&
                  (currentTierName == 'pro' || currentTierName == 'premium')));
      return row;
    }).toList();
    return PricingCatalogueResponse.fromJson(json);
  }

  @override
  Future<void> selectPlan({
    required String tierId,
    required String billingCycle,
  }) async {
    if (!{'annual', 'monthly'}.contains(billingCycle)) {
      throw ArgumentError('Unknown billing cycle');
    }
    final catalogue = await getPricingCatalogue();
    final plan = catalogue.plans.firstWhere(
      (p) => p.id == tierId,
      orElse: () => throw ArgumentError('Unknown plan'),
    );
    if (!plan.isCurrent && (!plan.isPurchasable || plan.tier != AppTier.free)) {
      throw StateError('Paid plans require verified store checkout.');
    }
    _session.startPeriod(AppTier.values.byName(plan.tier.name), billingCycle);
  }
}
