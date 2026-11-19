import 'package:url_launcher/url_launcher.dart';

Future<bool> installAppUpdate(Uri? updateUri) async {
  if (updateUri == null) return false;
  return launchUrl(updateUri, mode: LaunchMode.externalApplication);
}
