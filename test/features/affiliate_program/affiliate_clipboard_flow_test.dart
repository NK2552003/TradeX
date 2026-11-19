import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:alphajournal/features/affiliate_program/data/affiliate_workspace_repository.dart';
import 'package:alphajournal/features/affiliate_program/presentation/pages/affiliate_overview_page.dart';

void main() {
  testWidgets('copy referral link copies the actual URL', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final repository = AffiliateWorkspaceRepository(demoOverride: true);
    final workspace = await repository.load();
    String? copied;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copied = (call.arguments as Map)['text'] as String;
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: AffiliateOverviewPage(repository: repository)),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    final copy = find.text('Copy Referral Link');
    await tester.ensureVisible(copy);
    await tester.tap(copy);
    await tester.pump();
    expect(copied, workspace.referralUrl);
  });
}
