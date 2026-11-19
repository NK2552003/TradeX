import 'package:flutter/material.dart';
// Required presentation imports.
// ignore: unused_import
import 'package:alphajournal/core/app-ui/app_ui.dart';
// ignore: unused_import
import 'package:alphajournal/core/flutter-ui/flutter_ui.dart';
import 'package:alphajournal/features/admin_console/data/admin_repository.dart';
import 'package:alphajournal/features/admin_console/models/admin_records.dart';
import 'package:alphajournal/features/admin_console/presentation/pages/admin_records_page.dart';

class AdminPublishingPage extends StatelessWidget {
  const AdminPublishingPage({super.key, this.repository});
  final AdminRepository? repository;

  @override
  Widget build(BuildContext context) => AdminRecordsPage(
    resource: AdminResource.posts,
    resources: const [AdminResource.posts, AdminResource.comments],
    title: 'Posts and review',
    repository: repository,
  );
}
