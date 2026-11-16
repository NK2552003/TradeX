import 'package:web/web.dart' as web;

String currentBrowserUserAgentImpl() {
  try {
    return web.window.navigator.userAgent;
  } catch (_) {
    return '';
  }
}
