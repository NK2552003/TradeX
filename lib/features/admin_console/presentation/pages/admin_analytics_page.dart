import 'package:flutter/material.dart';
// Required presentation imports.
// ignore: unused_import
import 'package:alphajournal/core/app-ui/app_ui.dart';
// ignore: unused_import
import 'package:alphajournal/core/flutter-ui/flutter_ui.dart';
import '../../data/admin_repository.dart';
import 'admin_overview_page.dart';

class AdminAnalyticsPage extends StatelessWidget {
  const AdminAnalyticsPage({super.key, this.onNavigate, this.repository});
  final ValueChanged<String>? onNavigate;
  final AdminRepository? repository;
  @override
  Widget build(BuildContext context) => AdminOverviewPage(
    analytics: true,
    onNavigate: onNavigate,
    repository: repository,
  );
}
