abstract class JournalRepository {
  Future<List<String>> getEntries();
}

class JournalRepositoryImpl implements JournalRepository {
  @override
  Future<List<String>> getEntries() async {
    return ['Sample entry'];
  }
}
