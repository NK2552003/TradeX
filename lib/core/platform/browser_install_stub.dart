import 'package:flutter/foundation.dart';

class BrowserInstall extends ChangeNotifier {
  static final instance = BrowserInstall();
  bool get available => false;
  bool get installed => false;
  bool get canSuggest => false;
  bool get supported => false;
  Future<String> prompt() async => 'unavailable';
  void dismiss() {}
  void refresh() {}
}
