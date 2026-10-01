import 'package:tradex/features/auth/models/pricing_models.dart';

/// The `content` column of public_site_pages; JSON arrays preserve editorial order.
class PublicSiteContent {
  PublicSiteContent.fromJson(this.json);
  final Map<String, dynamic> json;
  String text(String key) => json[key] as String? ?? '';
  List<Map<String, dynamic>> rows(String key) => (json[key] as List? ?? [])
      .map((e) => Map<String, dynamic>.from(e as Map))
      .toList();
  List<PricingFaqItem> get faqs =>
      rows('faqs').map(PricingFaqItem.fromJson).toList();
}
