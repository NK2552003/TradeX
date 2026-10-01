import 'package:flutter/material.dart';
import 'package:tradex/features/market_data/data/asset_market_repository.dart';
import 'package:tradex/features/market_data/presentation/market_movers_panel.dart';

/// Compact community context; the complete browser lives in Market Intelligence.
class MarketSidebar extends StatelessWidget {
  const MarketSidebar({super.key, this.repository});
  final AssetMarketRepository? repository;
  @override
  Widget build(BuildContext context) =>
      MarketMoversPanel(repository: repository);
}
