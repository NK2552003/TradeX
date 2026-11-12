import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'core/app-ui/app_ui.dart';
// ignore: unnecessary_import
import 'core/flutter-ui/flutter_ui.dart';
import 'core/ads/ad_config.dart';
import 'core/ads/ad_scope.dart';
import 'core/ads/ad_slot.dart';

/// Local-only placement gallery; never loads a Google script or serves an ad.
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;
  runApp(
    UiApp(
      theme: UiTheme.dark(),
      builder: (_) => const MaterialApp(
        debugShowCheckedModeBanner: false,
        home: AdPlacementPreview(),
      ),
    ),
  );
}

class AdPlacementPreview extends StatefulWidget {
  const AdPlacementPreview({super.key});
  @override
  State<AdPlacementPreview> createState() => _AdPlacementPreviewState();
}

class _AdPlacementPreviewState extends State<AdPlacementPreview> {
  bool _paid = false;
  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: context.ui.colors.background,
    body: AdSenseScope(
      eligible: !_paid,
      config: const AdConfig(preview: true),
      child: UiPage(
        title: 'Advertising placements',
        subtitle: 'Layout preview only. No live advertisements or tracking.',
        maxWidth: 1060,
        actions: [
          UiButton(
            label: _paid ? 'Show free plan' : 'Show paid plan',
            onPressed: () => setState(() => _paid = !_paid),
          ),
        ],
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            UiCallout(
              title: _paid
                  ? 'Paid plan — no advertising'
                  : 'Free plan placements',
              message:
                  'Public reading surfaces have clearly labelled ad spaces. Private work remains separate.',
            ),
            for (final placement in AdPlacement.values) ...[
              UiGap.v(context.ui.spacing.lg),
              Text(
                placement.id.replaceAll('_', ' '),
                style: context.uiText.subheading,
              ),
              AdSlot(placement: placement),
            ],
          ],
        ),
      ),
    ),
  );
}
