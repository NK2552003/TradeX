abstract class WatchlistRepository {
  Future<List<String>> getWatchlists();
}

class WatchlistRepositoryImpl implements WatchlistRepository {
  @override
  Future<List<String>> getWatchlists() async {
    return ['Favorites'];
  }
}
