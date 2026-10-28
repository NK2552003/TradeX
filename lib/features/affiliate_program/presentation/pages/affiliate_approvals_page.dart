import 'package:flutter/material.dart';
// Required presentation imports.
// ignore: unused_import
import 'package:tradex/core/app-ui/app_ui.dart';
// ignore: unused_import
import 'package:tradex/core/flutter-ui/flutter_ui.dart';
import 'package:tradex/features/admin_console/data/admin_repository.dart';
import 'package:tradex/features/admin_console/models/admin_records.dart';
import 'package:tradex/features/admin_console/presentation/pages/admin_records_page.dart';

class AffiliateApprovalsPage extends StatelessWidget {
  const AffiliateApprovalsPage({super.key, this.repository});
  final AdminRepository? repository;

  @override
  Widget build(BuildContext context) => AdminRecordsPage(
    resource: AdminResource.applications,
    resources: const [
      AdminResource.applications,
      AdminResource.affiliates,
      AdminResource.payouts,
    ],
    title: 'Affiliates',
    repository: repository,
  );
}
