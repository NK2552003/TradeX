import 'package:flutter/material.dart';
import 'package:tradex/core/app-ui/app_ui.dart';
import 'package:tradex/core/flutter-ui/flutter_ui.dart';

import '../../data/admin_repository.dart';
import '../../models/admin_records.dart';
import '../widgets/admin_records_panel.dart';
import 'admin_record_detail_page.dart';
import 'admin_user_detail_page.dart';

class AdminRecordsPage extends StatefulWidget {
  const AdminRecordsPage({
    super.key,
    required this.resource,
    this.resources,
    this.title,
    this.repository,
    this.initialStatus = 'all',
  });
  final AdminResource resource;
  final List<AdminResource>? resources;
  final String? title;
  final AdminRepository? repository;
  final String initialStatus;
  @override
  State<AdminRecordsPage> createState() => _AdminRecordsPageState();
}

class _AdminRecordsPageState extends State<AdminRecordsPage> {
  late AdminResource _resource = widget.resource;
  AdminRecord? _record;
  String? _userId;
  String _userTab = 'Overview';
  int _revision = 0;
  AdminRepository get _repo => widget.repository ?? AdminRepository.instance;

  @override
  void didUpdateWidget(covariant AdminRecordsPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.resource != widget.resource) {
      _resource = widget.resource;
      _record = null;
      _userId = null;
      _revision++;
    }
  }

  void _open(AdminRecord row) {
    setState(() {
      if ([
        AdminResource.users,
        AdminResource.subscriptions,
        AdminResource.affiliates,
      ].contains(_resource)) {
        _userId = row.userId ?? row.id;
        _userTab = _resource == AdminResource.subscriptions
            ? 'Subscription'
            : _resource == AdminResource.affiliates
            ? 'Affiliate'
            : 'Overview';
      } else {
        _record = row;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_userId != null) {
      return AdminUserDetailPage(
        key: ValueKey(_userId),
        userId: _userId!,
        repository: _repo,
        initialTab: _userTab,
        onBack: () => setState(() {
          _userId = null;
          _revision++;
        }),
      );
    }
    if (_record != null) {
      return AdminRecordDetailPage(
        key: ValueKey(_record!.id),
        resource: _resource,
        recordId: _record!.id,
        repository: _repo,
        onBack: () => setState(() {
          _record = null;
          _revision++;
        }),
        onOpenUser: (id) => setState(() {
          _userId = id;
          _userTab = 'Overview';
        }),
      );
    }
    final resources = widget.resources ?? [widget.resource];
    return UiPage(
      title: widget.title ?? _resource.label,
      subtitle: switch (_resource) {
        AdminResource.users =>
          'Manage accounts, permissions, subscriptions and user activity',
        AdminResource.applications =>
          'Review applications and manage existing affiliate accounts',
        AdminResource.posts || AdminResource.comments =>
          'Review content and inspect each post’s recorded engagement',
        AdminResource.activity =>
          'Recorded user actions and administrator decisions',
        AdminResource.subscriptions =>
          'Billing records and effective app access for every user',
        AdminResource.deletions =>
          'Review, cancel or complete account deletion requests',
        _ =>
          'Search stored records and open a record or its owner for controls',
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (resources.length > 1) ...[
            UiTabs(
              tabs: resources.map((resource) => resource.label).toList(),
              scrollable: true,
              selectedIndex: resources.indexOf(_resource),
              onChanged: (index) => setState(() {
                _resource = resources[index];
                _revision++;
              }),
            ),
            const UiGap.v(16),
          ],
          AdminRecordsPanel(
            key: ValueKey('${_resource.name}-$_revision'),
            resource: _resource,
            repository: _repo,
            initialStatus: _resource == widget.resource
                ? widget.initialStatus
                : 'all',
            onOpen: _open,
          ),
        ],
      ),
    );
  }
}
