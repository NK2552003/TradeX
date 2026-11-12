import 'package:flutter/material.dart';
import '../app-ui/app_ui.dart';
// ignore: unnecessary_import
import '../flutter-ui/flutter_ui.dart';
import 'ad_config.dart';
import 'ad_scope.dart';
import 'ad_platform.dart';

/// Manual, labelled placements. No click overlays, sticky banners or auto refresh.
class AdSlot extends StatefulWidget {
  const AdSlot({
    super.key,
    required this.placement,
    this.contentReady = true,
    this.previewContentReady,
    this.occurrence = 0,
  });
  final AdPlacement placement;
  final bool contentReady;

  /// Distinguishes repeated feed units without using any record or user data.
  final int occurrence;

  /// Allow development placeholders before content meets live-ad requirements.
  /// Callers must still exclude private records and non-advertising surfaces.
  final bool? previewContentReady;
  @override
  State<AdSlot> createState() => _AdSlotState();
}

class _AdSlotState extends State<AdSlot> with AutomaticKeepAliveClientMixin {
  bool _unfilled = false;
  @override
  bool get wantKeepAlive => true;
  @override
  Widget build(BuildContext context) {
    super.build(context);
    final ads = AdSenseScope.maybeOf(context);
    if (ads == null) return const SizedBox.shrink();
    final contentReady = ads.config.preview
        ? (widget.previewContentReady ?? widget.contentReady)
        : widget.contentReady;
    if (!contentReady || !ads.shows(widget.placement) || _unfilled) {
      return const SizedBox.shrink();
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final rail = widget.placement == AdPlacement.communityRail;
        final feed = widget.placement.isFeed;
        final available = constraints.maxWidth;
        if (!available.isFinite ||
            available < 250 ||
            (rail && available < 300)) {
          return const SizedBox.shrink();
        }
        // Feed units use the whole post column with a reserved 250px height.
        final width = feed
            ? available
            : rail
            ? 300.0
            : available >= 728
            ? 728.0
            : available >= 320
            ? 300.0
            : 250.0;
        final height = rail || feed
            ? 250.0
            : width >= 728
            ? 90.0
            : 250.0;
        return Padding(
          padding: EdgeInsets.symmetric(
            vertical: context.sp(context.ui.spacing.xl),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Advertisement',
                style: context.uiText.caption.copyWith(
                  color: context.ui.colors.foregroundMuted,
                ),
              ),
              UiGap.v(context.ui.spacing.sm),
              SizedBox(
                width: width,
                height: height,
                child: ads.config.preview
                    ? UiCard(
                        variant: UiCardVariant.subtle,
                        child: Center(
                          child: height < 100
                              ? Text(
                                  '${width.toInt()} × ${height.toInt()} · ${widget.placement.id.replaceAll('_', ' ')} · Preview only',
                                  style: context.uiText.caption,
                                )
                              : Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.ad_units_outlined,
                                      color: context.ui.colors.foregroundSubtle,
                                    ),
                                    UiGap.v(context.ui.spacing.sm),
                                    Text(
                                      '${width.toInt()} × ${height.toInt()}',
                                      style: context.uiText.bodyStrong,
                                    ),
                                    Text(
                                      '${widget.placement.id.replaceAll('_', ' ')}${widget.occurrence > 0 ? ' · ${widget.occurrence}' : ''}',
                                      style: context.uiText.caption,
                                    ),
                                    Text(
                                      'Preview · no live ad',
                                      style: context.uiText.caption,
                                    ),
                                  ],
                                ),
                        ),
                      )
                    : adPlatformView(
                        placement: widget.placement,
                        occurrence: widget.occurrence,
                        width: width,
                        height: height,
                        onState: (status) {
                          if (status == 'unfilled' || status == 'error') {
                            WidgetsBinding.instance.addPostFrameCallback((_) {
                              if (mounted) setState(() => _unfilled = true);
                            });
                          }
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}
