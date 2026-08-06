abstract class PortfolioRepository {
  Future<Map<String, dynamic>> getSummary();
}

class PortfolioRepositoryImpl implements PortfolioRepository {
  @override
  Future<Map<String, dynamic>> getSummary() async {
    return {'balance': 10000, 'pnl': 1250};
  }
}
