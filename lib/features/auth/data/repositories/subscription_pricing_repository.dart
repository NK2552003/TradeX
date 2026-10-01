import 'package:tradex/core/app-ui/theme/app_tokens.dart';
import 'package:tradex/core/data/app_session.dart';
import 'package:tradex/core/data/demo_data_source.dart';
import 'package:tradex/features/auth/models/pricing_models.dart';
import 'package:tradex/features/public_site/data/public_site_repository.dart';

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
    json['plans'] = (json['plans'] as List).map((raw) {
      final row = Map<String, dynamic>.from(raw as Map);
      row['is_current'] = row['tier'] == _session.tier.value.name;
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
    // Local onboarding state only. Paid checkout must be confirmed server-side.
    _session.startPeriod(AppTier.values.byName(plan.tier.name), billingCycle);
  }
}
