import 'package:flutter/material.dart';

import '../../flutter-ui/flutter_ui.dart';
import '../theme/app_tokens.dart';

/// A step-by-step guide overlay for feature onboarding.
///
/// Shows contextual guidance with:
/// - Progress indicator
/// - Step content (title, description, optional illustration)
/// - Navigation controls (Next, Previous, Skip, Done)
/// - "Don't show again" option
class AppFeatureGuide extends StatefulWidget {
  const AppFeatureGuide({
    super.key,
    required this.steps,
    this.onComplete,
    this.onDismiss,
    this.dontShowAgainKey,
    this.initialStep = 0,
  });

  /// List of guide steps to display
  final List<AppGuideStep> steps;

  /// Called when user completes all steps
  final VoidCallback? onComplete;

  /// Called when user dismisses the guide
  final VoidCallback? onDismiss;

  /// Key for storing "don't show again" preference
  final String? dontShowAgainKey;

  /// Starting step index
  final int initialStep;

  @override
  State<AppFeatureGuide> createState() => _AppFeatureGuideState();
}

class _AppFeatureGuideState extends State<AppFeatureGuide> {
  late int _currentStep;
  bool _dontShowAgain = false;

  @override
  void initState() {
    super.initState();
    _currentStep = widget.initialStep;
  }

  bool get _isLastStep => _currentStep == widget.steps.length - 1;
  bool get _isFirstStep => _currentStep == 0;

  @override
  Widget build(BuildContext context) {
    final UiTheme theme = context.ui;
    final AppGuideStep step = widget.steps[_currentStep];
    final bool isMobile = context.uiRes.isMobile;

    return Container(
      decoration: BoxDecoration(
        color: context.uiColors.background,
        borderRadius: context.radius(theme.radii.xl),
        border: Border.all(color: context.uiColors.border),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      padding: EdgeInsets.all(context.sp(isMobile ? theme.spacing.lg : theme.spacing.xl)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          // Header with progress
          _buildHeader(context, isMobile),
          SizedBox(height: context.sp(theme.spacing.lg)),
          
          // Step content
          Expanded(
            child: _buildContent(context, step, isMobile),
          ),
          
          // Navigation
          SizedBox(height: context.sp(theme.spacing.lg)),
          _buildNavigation(context, isMobile),
          
          // Don't show again
          if (!isMobile && !widget.dontShowAgainKey.isNullOrEmpty()) ...<Widget>[
            SizedBox(height: context.sp(theme.spacing.md)),
            Row(
              children: <Widget>[
                UiCheckbox(
                  value: _dontShowAgain,
                  label: "Don't show again",
                  onChanged: (bool value) => setState(() => _dontShowAgain = value),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context, bool isMobile) {
    final UiTheme theme = context.ui;

    return Column(
      children: <Widget>[
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: <Widget>[
            Text(
              'Step ${_currentStep + 1} of ${widget.steps.length}',
              style: context.uiText.label.copyWith(
                color: context.uiColors.foregroundMuted,
              ),
            ),
            UiIconButton(
              icon: Icons.close_rounded,
              tooltip: 'Close',
              size: UiSize.sm,
              onPressed: () => widget.onDismiss?.call(),
            ),
          ],
        ),
        SizedBox(height: context.sp(theme.spacing.md)),
        // Progress bar
        ClipRRect(
          borderRadius: context.radius(theme.radii.full),
          child: LinearProgressIndicator(
            value: (_currentStep + 1) / widget.steps.length,
            backgroundColor: context.uiColors.surfaceMuted,
            valueColor: AlwaysStoppedAnimation<Color>(
              context.uiColors.primary,
            ),
            minHeight: 4,
          ),
        ),
      ],
    );
  }

  Widget _buildContent(BuildContext context, AppGuideStep step, bool isMobile) {
    final UiTheme theme = context.ui;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          if (step.illustration != null) ...<Widget>[
            Center(
              child: Container(
                width: context.sz(isMobile ? 160 : 200),
                height: context.sz(isMobile ? 120 : 140),
                margin: EdgeInsets.only(bottom: context.sp(theme.spacing.lg)),
                child: step.illustration,
              ),
            ),
          ],
          Text(
            step.title,
            style: isMobile ? context.uiText.title : context.uiText.display,
          ),
          SizedBox(height: context.sp(theme.spacing.md)),
          Text(
            step.description,
            style: context.uiText.body.copyWith(
              color: context.uiColors.foregroundMuted,
            ),
          ),
          if (step.tips.isNotEmpty) ...<Widget>[
            SizedBox(height: context.sp(theme.spacing.lg)),
            Container(
              padding: EdgeInsets.all(context.sp(theme.spacing.md)),
              decoration: BoxDecoration(
                color: context.uiColors.surfaceMuted,
                borderRadius: context.radius(theme.radii.lg),
                border: Border.all(color: context.uiColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Icon(
                        Icons.lightbulb_outline_rounded,
                        size: context.sz(16),
                        color: context.uiColors.warning,
                      ),
                      SizedBox(width: context.sp(theme.spacing.xs)),
                      Text(
                        'Tips',
                        style: context.uiText.labelStrong,
                      ),
                    ],
                  ),
                  SizedBox(height: context.sp(theme.spacing.sm)),
                  ...step.tips.map((String tip) => Padding(
                    padding: EdgeInsets.only(bottom: context.sp(theme.spacing.xxs)),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Icon(
                          Icons.check_circle_outline_rounded,
                          size: context.sz(14),
                          color: context.uiColors.bullish,
                        ),
                        SizedBox(width: context.sp(theme.spacing.xs)),
                        Expanded(
                          child: Text(
                            tip,
                            style: context.uiText.caption,
                          ),
                        ),
                      ],
                    ),
                  )),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildNavigation(BuildContext context, bool isMobile) {
    final UiTheme theme = context.ui;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: <Widget>[
        if (!_isFirstStep)
          UiButton(
            label: 'Previous',
            variant: UiVariant.outline,
            size: isMobile ? UiSize.sm : UiSize.md,
            expandOnMobile: false,
            onPressed: () => setState(() => _currentStep--),
          )
        else
          const SizedBox.shrink(),
        Row(
          children: <Widget>[
            if (!_isLastStep)
              UiButton(
                label: 'Skip',
                variant: UiVariant.ghost,
                size: isMobile ? UiSize.sm : UiSize.md,
                expandOnMobile: false,
                onPressed: () {
                  widget.onDismiss?.call();
                },
              )
            else
              const SizedBox.shrink(),
            SizedBox(width: context.sp(theme.spacing.sm)),
            UiButton(
              label: _isLastStep ? 'Get Started' : 'Next',
              variant: UiVariant.filled,
              size: isMobile ? UiSize.sm : UiSize.md,
              expandOnMobile: false,
              onPressed: () {
                if (_isLastStep) {
                  if (widget.dontShowAgainKey != null && _dontShowAgain) {
                    // Store preference (implementation depends on persistence layer)
                  }
                  widget.onComplete?.call();
                } else {
                  setState(() => _currentStep++);
                }
              },
            ),
          ],
        ),
      ],
    );
  }
}

/// A single step in the feature guide.
class AppGuideStep {
  const AppGuideStep({
    required this.title,
    required this.description,
    this.illustration,
    this.tips = const <String>[],
  });

  /// Step title
  final String title;

  /// Step description
  final String description;

  /// Optional illustration widget
  final Widget? illustration;

  /// Helpful tips for this step
  final List<String> tips;
}

extension on String {
  bool isNullOrEmpty() => isEmpty;
}
