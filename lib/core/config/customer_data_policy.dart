/// Sample customer records are opt-in for isolated previews and tests only.
class CustomerDataPolicy {
  CustomerDataPolicy._();
  static bool allowDemo = false;

  static String? developmentPreview(Uri uri, {required bool debug}) {
    if (!debug || !allowDemo) return null;
    final mode = uri.queryParameters['preview'];
    return const {
          'application',
          'pricing',
          'subscription',
          'customer',
          'affiliate',
          'admin',
        }.contains(mode)
        ? mode
        : null;
  }
}
