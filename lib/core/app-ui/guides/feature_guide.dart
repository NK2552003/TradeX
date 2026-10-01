import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../../flutter-ui/flutter_ui.dart';
import 'guide_steps.dart';

/// Interactive feature guides — the shared "new here?" framework behind the
/// Strategies, Journal and Notes landing pages.
///
/// The framework is deliberately ignorant of the app it guides. [FeatureId]
/// names the feature, the [FeatureGuideStep]s passed in by the caller (see
/// `guide_steps.dart` for the ready-made walkthroughs) say what each step is,
/// and the owning screen resolves a step's action into real navigation through
/// [FeatureGuideSheet.onStepAction]. All strings and steps travel in as data;
/// nothing here hardcodes a feature screen or a record.
///
/// State lives in [FeatureGuideController], a per-feature in-memory singleton:
/// steps seen, steps done, dismissed. It is deliberately not persisted — a
/// walkthrough that nags across restarts is onboarding nobody asked for, and
/// `reset()` exists precisely so support can restart one.
///
/// The two renderings share the same progress model. [FeatureGuideBanner] is a
/// compact, dismissible, *never modal* strip that sits at the top of a landing
/// page; [FeatureGuideSheet] is the step-by-step walkthrough itself — a bottom
/// sheet on phones, a right-hand panel on larger screens.

// ── Feature identity ─────────────────────────────────────────────────────────

/// The features that ship a guide.
///
/// Keys the controller's per-feature state and selects the ready-made step
/// lists in `guide_steps.dart`.
enum FeatureId { strategies, journal, notes }

// ── Controller ───────────────────────────────────────────────────────────────

/// In-memory progress for one feature's guide.
class FeatureGuideController extends ChangeNotifier {
  FeatureGuideController._();

  /// App-wide singleton. Widgets read it through a [ListenableBuilder], so a
  /// step marked done in one surface updates the banner on every other one
  /// still mounted.
  static final FeatureGuideController instance = FeatureGuideController._();

  final Map<FeatureId, _FeatureGuideState> _states =
      <FeatureId, _FeatureGuideState>{};

  _FeatureGuideState _state(FeatureId feature) =>
      _states.putIfAbsent(feature, _FeatureGuideState.new);

  bool _notifyScheduled = false;

  /// Notifies listeners, but never in the middle of a build or layout pass.
  ///
  /// [attach] runs from a banner's `initState`, and a banner can be mounted
  /// lazily while a sliver is laying out. Notifying synchronously there would
  /// mark every other guide `ListenableBuilder` dirty during build — the
  /// "setState() called during build" crash. When a frame is already in flight
  /// we coalesce to a single notification at the end of it; otherwise we notify
  /// at once. The singleton is never disposed, so the deferred call is safe.
  void _notify() {
    final SchedulerBinding binding = SchedulerBinding.instance;
    final SchedulerPhase phase = binding.schedulerPhase;
    if (phase == SchedulerPhase.idle ||
        phase == SchedulerPhase.postFrameCallbacks) {
      notifyListeners();
      return;
    }
    if (_notifyScheduled) return;
    _notifyScheduled = true;
    binding.addPostFrameCallback((_) {
      _notifyScheduled = false;
      notifyListeners();
    });
  }

  /// Tells the controller how long this feature's walkthrough is.
  ///
  /// The step lists are data owned by the caller (the banner and sheet both
  /// call this with the `steps` they were given), so the controller never has
  /// to know which steps a feature ships. Repeated calls with the same count
  /// are no-ops; a changed count only happens when a walkthrough is edited,
  /// and simply overrides.
  void attach(FeatureId feature, int stepCount) {
    final _FeatureGuideState state = _state(feature);
    if (state.total == stepCount) return;
    state.total = stepCount;
    _notify();
  }

  /// Records that the trader has looked at a step. Never unmarks.
  void markStepSeen(FeatureId feature, int stepIndex) {
    final _FeatureGuideState state = _state(feature);
    if (_outOfRange(state, stepIndex)) return;
    if (state.seen.add(stepIndex)) _notify();
  }

  /// Records that the trader has actually done the step — either by pressing
  /// its action button or by finishing the walkthrough. Implies seen.
  void markStepDone(FeatureId feature, int stepIndex) {
    final _FeatureGuideState state = _state(feature);
    if (_outOfRange(state, stepIndex)) return;
    state.seen.add(stepIndex);
    if (state.done.add(stepIndex)) _notify();
  }

  /// Hides the banner for the rest of the session. `reset()` brings it back.
  void dismiss(FeatureId feature) {
    final _FeatureGuideState state = _state(feature);
    if (state.dismissed) return;
    state.dismissed = true;
    _notify();
  }

  /// Clears every trace of progress and dismissal for one feature, so its
  /// first-run banner and walkthrough start over. The support escape hatch.
  void reset(FeatureId feature) {
    if (_states.remove(feature) != null) _notify();
  }

  // ── Progress ───────────────────────────────────────────────────────────────

  /// Steps the trader has completed, out of [totalSteps].
  int doneCount(FeatureId feature) => _states[feature]?.done.length ?? 0;

  /// Steps this feature's guide has, per the last [attach].
  int totalSteps(FeatureId feature) => _states[feature]?.total ?? 0;

  /// 0..1 — finished over total. Zero when nothing has been attached yet.
  double progress(FeatureId feature) {
    final _FeatureGuideState? state = _states[feature];
    if (state == null || state.total == 0) return 0;
    return state.done.length / state.total;
  }

  /// Every step done (and the guide knows how many there are).
  bool isComplete(FeatureId feature) {
    final _FeatureGuideState? state = _states[feature];
    return state != null && state.total > 0 && state.done.length >= state.total;
  }

  /// The trader dismissed this feature's banner this session.
  bool isDismissed(FeatureId feature) => _states[feature]?.dismissed ?? false;

  bool hasSeen(FeatureId feature, int stepIndex) {
    final _FeatureGuideState? state = _states[feature];
    return state != null && state.seen.contains(stepIndex);
  }

  bool hasDone(FeatureId feature, int stepIndex) {
    final _FeatureGuideState? state = _states[feature];
    return state != null && state.done.contains(stepIndex);
  }

  /// The first step the trader has not finished — where "Show guide" should
  /// resume. Zero when nothing is done yet.
  int nextStepIndex(FeatureId feature) {
    final _FeatureGuideState? state = _states[feature];
    if (state == null) return 0;
    for (int i = 0; i < state.total; i++) {
      if (!state.done.contains(i)) return i;
    }
    return state.total == 0 ? 0 : state.total - 1;
  }

  static bool _outOfRange(_FeatureGuideState state, int stepIndex) =>
      state.total > 0 && (stepIndex < 0 || stepIndex >= state.total);
}

class _FeatureGuideState {
  int total = 0;
  bool dismissed = false;
  final Set<int> seen = <int>{};
  final Set<int> done = <int>{};
}

// ── Banner ───────────────────────────────────────────────────────────────────

/// Compact, dismissible first-run strip for a landing page.
///
/// Progress-aware in three states: while the walkthrough is unfinished it
/// carries the pitch ("New here? Follow the 5-step setup"), the running count
/// ("2 of 5 done") and a "Show guide" button; once every step is done it
/// collapses to a slim one-line "Reopen guide" chip; dismissed removes it for
/// the session. It is a row of page chrome, never a modal — [onShowGuide]
/// opens the walkthrough the same way the page header's "Guide" button will.
class FeatureGuideBanner extends StatefulWidget {
  const FeatureGuideBanner({
    super.key,
    required this.feature,
    required this.steps,
    required this.onShowGuide,
    this.onDismiss,
  });

  final FeatureId feature;

  /// The walkthrough this banner pitches. Only the length is read.
  final List<FeatureGuideStep> steps;

  /// Opens the walkthrough — wire it to [FeatureGuideSheet.show].
  final VoidCallback onShowGuide;

  /// Extra hook fired when the trader dismisses the strip (the controller
  /// already records the dismissal; this is for analytics or focus shifts).
  final VoidCallback? onDismiss;

  @override
  State<FeatureGuideBanner> createState() => _FeatureGuideBannerState();
}

class _FeatureGuideBannerState extends State<FeatureGuideBanner> {
  FeatureGuideController get _controller => FeatureGuideController.instance;

  @override
  void initState() {
    super.initState();
    _controller.attach(widget.feature, widget.steps.length);
  }

  @override
  void didUpdateWidget(covariant FeatureGuideBanner oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.feature != widget.feature ||
        !identical(oldWidget.steps, widget.steps)) {
      _controller.attach(widget.feature, widget.steps.length);
    }
  }

  void _dismiss() {
    _controller.dismiss(widget.feature);
    widget.onDismiss?.call();
  }

  @override
  Widget build(BuildContext context) {
    // A guide with no steps has nothing to pitch, complete or otherwise.
    if (widget.steps.isEmpty) return const SizedBox.shrink();
    return ListenableBuilder(
      listenable: _controller,
      builder: (BuildContext context, _) {
        final FeatureGuideController controller = _controller;
        if (controller.isDismissed(widget.feature)) {
          return const SizedBox.shrink();
        }
        if (controller.isComplete(widget.feature)) {
          return _ReopenChip(
            onShowGuide: widget.onShowGuide,
            onDismiss: _dismiss,
          );
        }
        return _PitchStrip(
          feature: widget.feature,
          stepCount: widget.steps.length,
          onShowGuide: widget.onShowGuide,
          onDismiss: _dismiss,
        );
      },
    );
  }
}

/// The full strip: pitch, live progress, and the entry points.
///
/// Layout follows the page it sits on — a stacked, full-width block on phones
/// where the "Show guide" button earns the whole row, and one inline row on
/// desktop where the button fits beside the copy.
class _PitchStrip extends StatelessWidget {
  const _PitchStrip({
    required this.feature,
    required this.stepCount,
    required this.onShowGuide,
    required this.onDismiss,
  });

  final FeatureId feature;
  final int stepCount;
  final VoidCallback onShowGuide;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final UiTheme theme = context.ui;
    final UiColors c = theme.colors;
    final FeatureGuideController controller = FeatureGuideController.instance;
    final int done = controller.doneCount(feature);

    final Widget icon = Container(
      width: context.sz(30),
      height: context.sz(30),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: c.primary.withValues(alpha: 0.12),
        borderRadius: context.radius(theme.radii.md),
      ),
      child: Icon(Icons.route_rounded, size: context.sz(16), color: c.primary),
    );

    final Widget copy = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(
          'New here? Follow the $stepCount-step setup',
          style: context.uiText.bodyStrong.copyWith(color: c.foreground),
        ),
        SizedBox(height: context.sp(theme.spacing.xxs)),
        Text(
          'From define to review — each step opens the exact screen it '
          'describes.',
          style: context.uiText.caption.copyWith(color: c.foregroundMuted),
        ),
      ],
    );

    final Widget progress = UiBadge(
      label: '$done of $stepCount done',
      icon: done == 0
          ? Icons.radio_button_unchecked_rounded
          : Icons.checklist_rounded,
      intent: done == 0 ? UiIntent.info : UiIntent.success,
      variant: UiBadgeVariant.soft,
      size: UiSize.xs,
    );

    final Widget showButton = UiButton(
      label: 'Show guide',
      leadingIcon: Icons.play_arrow_rounded,
      size: UiSize.sm,
      variant: UiVariant.secondary,
      expandOnMobile: true,
      onPressed: onShowGuide,
    );

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        // A phone screen and the desktop workbench's narrow index rail both
        // need the stacked shape; the inline row only fits once there is real
        // width for the pitch, the progress and the button.
        final bool mobile =
            context.uiRes.isMobile || constraints.maxWidth < context.sz(560);
        return UiCard(
          variant: UiCardVariant.outlined,
          density: UiDensity.compact,
          accentColor: c.primary,
          padding: EdgeInsets.symmetric(
            horizontal: context.sp(theme.spacing.sm),
            vertical: context.sp(theme.spacing.sm),
          ),
          child: mobile
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        icon,
                        SizedBox(width: context.sp(theme.spacing.sm)),
                        Expanded(child: copy),
                        UiIconButton(
                          icon: Icons.close_rounded,
                          size: UiSize.xs,
                          tooltip: 'Dismiss guide',
                          onPressed: onDismiss,
                        ),
                      ],
                    ),
                    SizedBox(height: context.sp(theme.spacing.sm)),
                    Row(children: <Widget>[progress, const Spacer()]),
                    SizedBox(height: context.sp(theme.spacing.xs)),
                    showButton,
                  ],
                )
              : Row(
                  children: <Widget>[
                    icon,
                    SizedBox(width: context.sp(theme.spacing.sm)),
                    Flexible(child: copy),
                    SizedBox(width: context.sp(theme.spacing.sm)),
                    progress,
                    SizedBox(width: context.sp(theme.spacing.md)),
                    showButton,
                    SizedBox(width: context.sp(theme.spacing.xs)),
                    UiIconButton(
                      icon: Icons.close_rounded,
                      size: UiSize.xs,
                      tooltip: 'Dismiss guide',
                      onPressed: onDismiss,
                    ),
                  ],
                ),
        );
      },
    );
  }
}

/// The finished state: one slim line so a completed feature stops nagging but
/// the walkthrough stays reachable for a replay.
class _ReopenChip extends StatelessWidget {
  const _ReopenChip({required this.onShowGuide, required this.onDismiss});

  final VoidCallback onShowGuide;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final UiTheme theme = context.ui;
    final UiColors c = theme.colors;
    return UiCard(
      variant: UiCardVariant.outlined,
      density: UiDensity.compact,
      padding: EdgeInsets.symmetric(
        horizontal: context.sp(theme.spacing.sm),
        vertical: context.sp(theme.spacing.xs),
      ),
      child: Row(
        children: <Widget>[
          Icon(
            Icons.check_circle_rounded,
            size: context.sz(14),
            color: c.bullish,
          ),
          SizedBox(width: context.sp(theme.spacing.xs)),
          Expanded(
            child: Text(
              'Guide complete',
              style: context.uiText.caption.copyWith(color: c.foregroundMuted),
            ),
          ),
          UiButton(
            label: 'Reopen guide',
            variant: UiVariant.ghost,
            size: UiSize.xs,
            onPressed: onShowGuide,
          ),
          SizedBox(width: context.sp(theme.spacing.xxs)),
          UiIconButton(
            icon: Icons.close_rounded,
            size: UiSize.xs,
            tooltip: 'Dismiss guide',
            onPressed: onDismiss,
          ),
        ],
      ),
    );
  }
}

// ── Spotlight tour ───────────────────────────────────────────────────────────

/// A contextual product tour that points at real controls instead of replacing
/// the interface with a modal card. Four dimmed bands leave the active target
/// visible and clickable; the coachmark sits beside it and uses icon-only
/// controls so the product remains the visual subject of the walkthrough.
abstract final class FeatureGuideSpotlight {
  static void show(
    BuildContext context, {
    required FeatureId feature,
    required List<FeatureGuideStep> steps,
    required List<GlobalKey> targets,
    ValueChanged<FeatureGuideStep>? onStepAction,
  }) {
    if (steps.isEmpty) return;
    final OverlayState overlay = Overlay.of(context, rootOverlay: true);
    late final OverlayEntry entry;
    entry = OverlayEntry(
      builder: (BuildContext overlayContext) => _FeatureGuideSpotlightOverlay(
        feature: feature,
        steps: steps,
        targets: targets,
        onStepAction: onStepAction,
        onClose: entry.remove,
      ),
    );
    overlay.insert(entry);
  }
}

class _FeatureGuideSpotlightOverlay extends StatefulWidget {
  const _FeatureGuideSpotlightOverlay({
    required this.feature,
    required this.steps,
    required this.targets,
    required this.onClose,
    this.onStepAction,
  });

  final FeatureId feature;
  final List<FeatureGuideStep> steps;
  final List<GlobalKey> targets;
  final ValueChanged<FeatureGuideStep>? onStepAction;
  final VoidCallback onClose;

  @override
  State<_FeatureGuideSpotlightOverlay> createState() =>
      _FeatureGuideSpotlightOverlayState();
}

class _FeatureGuideSpotlightOverlayState
    extends State<_FeatureGuideSpotlightOverlay> {
  final FeatureGuideController _controller = FeatureGuideController.instance;
  late int _index;
  Rect? _target;

  @override
  void initState() {
    super.initState();
    _controller.attach(widget.feature, widget.steps.length);
    _index = _controller
        .nextStepIndex(widget.feature)
        .clamp(0, widget.steps.length - 1);
    _controller.markStepSeen(widget.feature, _index);
    _scheduleMeasure();
  }

  void _scheduleMeasure() => WidgetsBinding.instance.addPostFrameCallback((_) {
    if (!mounted) return;
    final BuildContext? targetContext = widget.targets.isEmpty
        ? null
        : widget.targets[_index % widget.targets.length].currentContext;
    final RenderObject? renderObject = targetContext?.findRenderObject();
    final Rect? next = renderObject is RenderBox && renderObject.hasSize
        ? renderObject.localToGlobal(Offset.zero) & renderObject.size
        : null;
    if (next != _target) setState(() => _target = next);
  });

  void _goTo(int index) {
    setState(() {
      _index = index;
      _target = null;
    });
    _controller.markStepSeen(widget.feature, index);
    _scheduleMeasure();
  }

  void _runAction() {
    final FeatureGuideStep step = widget.steps[_index];
    _controller.markStepDone(widget.feature, _index);
    widget.onStepAction?.call(step);
    widget.onClose();
  }

  void _next() {
    final bool last = _index == widget.steps.length - 1;
    if (last) {
      _controller.markStepDone(widget.feature, _index);
      widget.onClose();
      return;
    }
    _goTo(_index + 1);
  }

  Widget _veil(Color color) => AbsorbPointer(child: ColoredBox(color: color));

  @override
  Widget build(BuildContext context) {
    final UiTheme theme = context.ui;
    final UiColors colors = theme.colors;
    final Size viewport = MediaQuery.sizeOf(context);
    final EdgeInsets safe = MediaQuery.paddingOf(context);
    final Rect focus =
        (_target ??
                Rect.fromLTWH(
                  viewport.width * .5 - context.sz(28),
                  safe.top + context.sz(12),
                  context.sz(56),
                  context.sz(44),
                ))
            .inflate(context.sp(theme.spacing.xs))
            .intersect(Offset.zero & viewport);
    final Color veil = colors.overlay.withValues(alpha: .82);
    final double gap = context.sp(theme.spacing.sm);
    final double cardWidth = (viewport.width - gap * 2).clamp(
      context.sz(280),
      context.sz(390),
    );
    final bool placeBelow = focus.bottom + context.sz(240) < viewport.height;
    final double cardTop = placeBelow
        ? focus.bottom + gap
        : (focus.top - context.sz(220) - gap).clamp(
            safe.top + gap,
            viewport.height - context.sz(230) - safe.bottom,
          );
    final double cardLeft = (focus.center.dx - cardWidth / 2).clamp(
      gap,
      viewport.width - cardWidth - gap,
    );
    final FeatureGuideStep step = widget.steps[_index];

    return Material(
      type: MaterialType.transparency,
      child: Stack(
        children: <Widget>[
          Positioned(
            left: 0,
            top: 0,
            right: 0,
            height: focus.top,
            child: _veil(veil),
          ),
          Positioned(
            left: 0,
            top: focus.bottom,
            right: 0,
            bottom: 0,
            child: _veil(veil),
          ),
          Positioned(
            left: 0,
            top: focus.top,
            width: focus.left,
            height: focus.height,
            child: _veil(veil),
          ),
          Positioned(
            left: focus.right,
            top: focus.top,
            right: 0,
            height: focus.height,
            child: _veil(veil),
          ),
          Positioned.fromRect(
            rect: focus,
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: context.radius(theme.radii.lg),
                  border: Border.all(
                    color: colors.primary,
                    width: theme.borders.thick,
                  ),
                  boxShadow: theme.shadows.lg,
                ),
              ),
            ),
          ),
          Positioned(
            left: cardLeft,
            top: cardTop,
            width: cardWidth,
            child: UiCard(
              variant: UiCardVariant.elevated,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      UiBadge(
                        label: '${_index + 1} / ${widget.steps.length}',
                        variant: UiBadgeVariant.soft,
                        intent: UiIntent.primary,
                      ),
                      const Spacer(),
                      UiIconButton(
                        icon: Icons.close_rounded,
                        tooltip: 'Close guide',
                        size: UiSize.sm,
                        onPressed: widget.onClose,
                      ),
                    ],
                  ),
                  SizedBox(height: context.sp(theme.spacing.sm)),
                  Text(step.title, style: context.uiText.subheading),
                  SizedBox(height: context.sp(theme.spacing.xs)),
                  Text(
                    step.why,
                    style: context.uiText.body.copyWith(
                      color: colors.foregroundMuted,
                    ),
                  ),
                  SizedBox(height: context.sp(theme.spacing.md)),
                  Text(
                    step.hasAction
                        ? 'Use the highlighted control, or start this step here.'
                        : 'Inspect the highlighted area, then continue.',
                    style: context.uiText.caption.copyWith(
                      color: colors.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(height: context.sp(theme.spacing.sm)),
                  Row(
                    children: <Widget>[
                      UiIconButton(
                        icon: Icons.arrow_back_rounded,
                        tooltip: 'Previous step',
                        size: UiSize.sm,
                        onPressed: _index == 0 ? null : () => _goTo(_index - 1),
                      ),
                      const Spacer(),
                      if (step.hasAction) ...<Widget>[
                        UiIconButton(
                          icon: Icons.touch_app_rounded,
                          tooltip: step.actionLabel,
                          size: UiSize.sm,
                          variant: UiVariant.primary,
                          onPressed: _runAction,
                        ),
                        SizedBox(width: context.sp(theme.spacing.xs)),
                      ],
                      UiIconButton(
                        icon: _index == widget.steps.length - 1
                            ? Icons.check_rounded
                            : Icons.arrow_forward_rounded,
                        tooltip: _index == widget.steps.length - 1
                            ? 'Finish guide'
                            : 'Next step',
                        size: UiSize.sm,
                        variant: step.hasAction
                            ? UiVariant.soft
                            : UiVariant.primary,
                        onPressed: _next,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Legacy embedded guide body ───────────────────────────────────────────────

/// Step-by-step walkthrough for one feature.
///
/// Each step shows its number ("Step 2 of 5"), its title, one why-it-matters
/// line, and — where the step is an action — a primary button. Pressing that
/// button marks the step done and hands it to [onStepAction]; the *owning
/// screen* resolves it into real navigation (open the gallery, file a trade,
/// promote to live), because only the feature knows where those screens are.
/// Back and Next move between steps; Next becomes Done on the final one.
///
/// Presented with [FeatureGuideSheet.show], which rides the existing
/// `UiDrawer` container: a bottom sheet on phones, a right-hand side panel
/// from tablet up. The widget itself is a plain body, so a screen could embed
/// it in a panel of its own.
class FeatureGuideSheet extends StatefulWidget {
  const FeatureGuideSheet({
    super.key,
    required this.feature,
    required this.steps,
    this.onStepAction,
    this.onComplete,
  });

  final FeatureId feature;
  final List<FeatureGuideStep> steps;

  /// Invoked when a step's action button is pressed, after the step is marked
  /// done. The owning screen navigates; the sheet stays open so the trader
  /// can return and keep going.
  final ValueChanged<FeatureGuideStep>? onStepAction;

  /// Fired when the trader finishes the final step.
  final VoidCallback? onComplete;

  /// Shows the walkthrough — a bottom sheet on phones, a right-hand panel on
  /// larger screens, via `UiDrawer.show`.
  static Future<void> show(
    BuildContext context, {
    required FeatureId feature,
    required List<FeatureGuideStep> steps,
    String title = 'Guide',
    ValueChanged<FeatureGuideStep>? onStepAction,
    VoidCallback? onComplete,
  }) => UiDrawer.show<void>(
    context,
    title: title,
    // The body owns its scrolling so the Back/Next bar stays pinned.
    scrollable: false,
    contentPadding: EdgeInsets.zero,
    child: FeatureGuideSheet(
      feature: feature,
      steps: steps,
      onStepAction: onStepAction,
      onComplete: onComplete,
    ),
  );

  @override
  State<FeatureGuideSheet> createState() => _FeatureGuideSheetState();
}

class _FeatureGuideSheetState extends State<FeatureGuideSheet> {
  late int _index;

  FeatureGuideController get _controller => FeatureGuideController.instance;

  @override
  void initState() {
    super.initState();
    _controller.attach(widget.feature, widget.steps.length);
    // Resume where the trader left off rather than restarting at step one
    // every time the sheet is reopened.
    _index = widget.steps.isEmpty
        ? 0
        : _controller
              .nextStepIndex(widget.feature)
              .clamp(0, widget.steps.length - 1);
    _controller.markStepSeen(widget.feature, _index);
  }

  @override
  void didUpdateWidget(covariant FeatureGuideSheet oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.feature != widget.feature ||
        !identical(oldWidget.steps, widget.steps)) {
      _controller.attach(widget.feature, widget.steps.length);
    }
  }

  void _goTo(int index) {
    setState(() => _index = index);
    _controller.markStepSeen(widget.feature, index);
  }

  void _doAction() {
    final FeatureGuideStep step = widget.steps[_index];
    _controller.markStepDone(widget.feature, _index);
    widget.onStepAction?.call(step);
    // On a phone the walkthrough is a bottom sheet, so the navigation it just
    // triggered lands underneath it. Pop the sheet so the trader sees where
    // they arrived; on larger surfaces the side panel stays open, which is
    // what keeps a multi-step walkthrough walkable.
    if (context.uiRes.isMobile) {
      Navigator.of(context).pop();
    }
  }

  void _finish() {
    _controller.markStepDone(widget.feature, _index);
    widget.onComplete?.call();
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final UiTheme theme = context.ui;
    final UiColors c = theme.colors;
    final List<FeatureGuideStep> steps = widget.steps;

    if (steps.isEmpty) {
      return const UiEmptyState(
        icon: Icons.route_outlined,
        title: 'Nothing to walk through yet',
        message:
            'This guide has no steps defined. Check the step list passed to '
            'FeatureGuideSheet.',
      );
    }

    final bool last = _index >= steps.length - 1;
    final FeatureGuideStep step = steps[_index];
    final int done = _controller.doneCount(widget.feature);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Expanded(
          child: SingleChildScrollView(
            padding: EdgeInsets.all(context.sp(theme.spacing.lg)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        'Step ${_index + 1} of ${steps.length}'.toUpperCase(),
                        style: uiOverline(context, color: c.foregroundMuted),
                      ),
                    ),
                    _StepDots(
                      total: steps.length,
                      current: _index,
                      doneCount: done,
                    ),
                  ],
                ),
                SizedBox(height: context.sp(theme.spacing.sm)),
                UiProgressBar(
                  value: (_index + 1) / steps.length,
                  intent: UiIntent.primary,
                  showValue: false,
                ),
                SizedBox(height: context.sp(theme.spacing.lg)),
                Text(
                  step.title,
                  style: context.uiText.subheading.copyWith(
                    color: c.foreground,
                  ),
                ),
                SizedBox(height: context.sp(theme.spacing.xs)),
                Text(
                  step.why,
                  style: context.uiText.body.copyWith(
                    color: c.foregroundMuted,
                    height: 1.45,
                  ),
                ),
                if (step.hasAction) ...<Widget>[
                  SizedBox(height: context.sp(theme.spacing.lg)),
                  UiButton(
                    label: step.actionLabel!,
                    leadingIcon: Icons.arrow_outward_rounded,
                    expandOnMobile: true,
                    onPressed: _doAction,
                  ),
                ],
              ],
            ),
          ),
        ),
        Container(height: theme.borders.hairline, color: c.border),
        Padding(
          padding: EdgeInsets.all(context.sp(theme.spacing.md)),
          child: Row(
            children: <Widget>[
              UiButton(
                label: 'Back',
                leadingIcon: Icons.arrow_back_rounded,
                variant: UiVariant.ghost,
                size: UiSize.sm,
                expandOnMobile: false,
                onPressed: _index == 0 ? null : () => _goTo(_index - 1),
              ),
              const Spacer(),
              UiButton(
                label: last ? 'Done' : 'Next',
                leadingIcon: last ? Icons.check_rounded : null,
                trailingIcon: last ? null : Icons.arrow_forward_rounded,
                variant: UiVariant.primary,
                size: UiSize.sm,
                expandOnMobile: false,
                onPressed: last ? _finish : () => _goTo(_index + 1),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// One dot per step: filled for the one on screen, checked when done, hollow
/// when still ahead. Sized as secondary chrome so it annotates the walkthrough
/// instead of competing with it.
class _StepDots extends StatelessWidget {
  const _StepDots({
    required this.total,
    required this.current,
    required this.doneCount,
  });

  final int total;
  final int current;
  final int doneCount;

  @override
  Widget build(BuildContext context) {
    final UiColors c = context.uiColors;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List<Widget>.generate(
        total,
        (int i) => Padding(
          padding: EdgeInsets.only(left: context.sp(context.uiSpace.xxs)),
          child: Icon(
            i < doneCount
                ? Icons.check_circle_rounded
                : (i == current ? Icons.circle : Icons.circle_outlined),
            size: context.sz(12),
            color: i < doneCount
                ? c.bullish
                : (i == current ? c.primary : c.borderStrong),
          ),
        ),
      ),
    );
  }
}
