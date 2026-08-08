import 'package:flutter/material.dart';
import 'package:tradex/core/flutter-ui/flutter_ui.dart';

class NavShellExampleView extends StatelessWidget {
  const NavShellExampleView({super.key});

  @override
  Widget build(BuildContext context) {
    return UiPage(
      header: const UiHeader(
        title: 'Trading Dashboard Page',
        subtitle: 'Responsive layout page header wrapper',
      ),
      child: Center(
        child: Text('Page body container rendered inside UiPage container.', style: context.uiText.body),
      ),
    );
  }
}
