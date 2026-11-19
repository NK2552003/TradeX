import 'package:flutter/material.dart';

import 'package:alphajournal/core/app-ui/app_ui.dart';
// ignore: unnecessary_import
import 'package:alphajournal/core/flutter-ui/flutter_ui.dart';
import 'package:alphajournal/core/privacy/consent_preferences.dart';
import 'package:alphajournal/features/affiliate_program/data/affiliate_attribution.dart';
import 'package:alphajournal/features/settings/data/cookie_notice_content.dart';

import 'publication_reader.dart';

enum _Purpose {
  essential(Icons.lock_outline_rounded),
  analytics(Icons.insights_rounded),
  advertising(Icons.campaign_outlined),
  personalizedAds(Icons.tune_rounded),
  affiliate(Icons.link_rounded);

  const _Purpose(this.icon);
  final IconData icon;

  bool allowed(ConsentPreferences prefs) => switch (this) {
    _Purpose.essential => true,
    _Purpose.analytics => prefs.analytics,
    _Purpose.advertising => prefs.advertising,
    _Purpose.personalizedAds => prefs.personalizedAds,
    _Purpose.affiliate => prefs.affiliate,
  };
}

class CookiePreferencesDialog extends StatefulWidget {
  const CookiePreferencesDialog({
    super.key,
    required this.controller,
    this.manage = false,
  });
  final ConsentController controller;
  final bool manage;

  static Future<void> show(
    BuildContext context, {
    bool manage = true,
    ConsentController? controller,
  }) async {
    final consent = controller ?? ConsentController.instance;
    await consent.initialize();
    await consent.refresh();
    if (!context.mounted) return;
    await UiDialog.show<void>(
      context,
      maxWidth: context.ui.breakpoints.mobile,
      pinFooter: true,
      blurBackdrop: true,
      child: CookiePreferencesDialog(controller: consent, manage: manage),
    );
  }

  @override
  State<CookiePreferencesDialog> createState() =>
      _CookiePreferencesDialogState();
}

class _CookiePreferencesDialogState extends State<CookiePreferencesDialog> {
  late final Future<CookieNoticeContent> _content = CookieNoticeContent.load();
  late Set<_Purpose>? _draft = widget.manage ? _savedChoices() : null;
  Set<_Purpose> _savedChoices() => {
    for (final purpose in _Purpose.values)
      if (purpose.allowed(widget.controller.value)) purpose,
  };

  Future<void> _save(Set<_Purpose> selected) async {
    final saved = await widget.controller.save(
      ConsentPreferences(
        analytics: selected.contains(_Purpose.analytics),
        advertising: selected.contains(_Purpose.advertising),
        personalizedAds: selected.contains(_Purpose.personalizedAds),
        affiliate: selected.contains(_Purpose.affiliate),
      ),
    );
    if (saved && mounted && ModalRoute.of(context)?.isCurrent == true) {
      Navigator.of(context).pop();
    }
  }

  void _toggle(_Purpose purpose, bool enabled) => setState(() {
    if (enabled) {
      _draft!.add(purpose);
    } else {
      _draft!.remove(purpose);
      if (purpose == _Purpose.advertising) {
        _draft!.remove(_Purpose.personalizedAds);
      }
    }
  });

  @override
  Widget build(BuildContext context) => FutureBuilder(
    future: _content,
    builder: (context, snapshot) {
      final copy = snapshot.data;
      if (copy == null) {
        return UiDialog(
          title: 'Cookie preferences',
          content: snapshot.hasError
              ? UiButton(
                  label: 'Continue with current choices',
                  onPressed: () => Navigator.of(context).pop(),
                )
              : UiSkeleton.text(lines: 3),
        );
      }
      return ListenableBuilder(
        listenable: widget.controller,
        builder: (context, _) => _notice(context, copy),
      );
    },
  );

  Widget _notice(BuildContext context, CookieNoticeContent copy) {
    final theme = context.ui;
    final busy = widget.controller.saving;
    final managing = _draft != null;
    final selected = _draft ?? _savedChoices();
    return UiDialog(
      leading: managing
          ? UiIconButton(
              icon: Icons.arrow_back_rounded,
              tooltip: copy['back'],
              onPressed: busy ? null : () => setState(() => _draft = null),
            )
          : AppLogoMark(size: theme.sizes.iconXl, rounded: true),
      title: copy[managing ? 'manageTitle' : 'summaryTitle'],
      description:
          copy[managing
              ? 'manageIntro'
              : widget.controller.needsChoice
              ? 'firstVisit'
              : 'returnVisit'],
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          UiCard(
            variant: UiCardVariant.subtle,
            padding: EdgeInsets.symmetric(
              horizontal: context.sp(theme.spacing.md),
            ),
            child: Column(
              children: [
                for (final purpose in _Purpose.values) ...[
                  if (purpose != _Purpose.essential)
                    UiDivider(spacing: theme.spacing.none),
                  _PurposeRow(
                    purpose: purpose,
                    copy: copy,
                    selected: selected.contains(purpose),
                    advertising: selected.contains(_Purpose.advertising),
                    managing: managing,
                    onChanged: busy ? null : (value) => _toggle(purpose, value),
                  ),
                ],
              ],
            ),
          ),
          UiGap.v(theme.spacing.md),
          Text(
            managing
                ? copy['retention'].replaceAll(
                    '{days}',
                    ConsentPreferences.lifetime.inDays.toString(),
                  )
                : copy['closeNotice'],
            style: context.uiText.caption.copyWith(
              color: theme.colors.foregroundMuted,
            ),
          ),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: UiButton(
              label: copy['policy'],
              variant: UiVariant.link,
              size: UiSize.sm,
              trailingIcon: Icons.arrow_forward_rounded,
              style: const UiButtonStyle(padding: EdgeInsets.zero),
              onPressed: busy
                  ? null
                  : () => PublicationReader.open(context, 'cookies'),
            ),
          ),
          if (widget.controller.error case final String error) ...[
            UiCallout(
              title: copy['error'],
              message: error,
              intent: UiIntent.warning,
            ),
            UiButton(
              label: copy['continue'],
              variant: UiVariant.ghost,
              onPressed: busy ? null : () => Navigator.of(context).pop(),
            ),
          ],
        ],
      ),
      footer: _CookieActions(
        copy: copy,
        managing: managing,
        busy: busy,
        onReject: () => _save({}),
        onAccept: () => _save(_Purpose.values.toSet()),
        onManageOrSave: () {
          if (managing) {
            _save(selected);
          } else {
            setState(() => _draft = _savedChoices());
          }
        },
      ),
    );
  }
}

class _PurposeRow extends StatelessWidget {
  const _PurposeRow({
    required this.purpose,
    required this.copy,
    required this.selected,
    required this.advertising,
    required this.managing,
    required this.onChanged,
  });
  final _Purpose purpose;
  final CookieNoticeContent copy;
  final bool selected, advertising, managing;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = context.ui;
    final fields = copy.purposes[purpose.name]!;
    final essential = purpose == _Purpose.essential;
    final dependsOnAds = purpose == _Purpose.personalizedAds && !advertising;
    final description = managing && dependsOnAds
        ? fields['requiresAdvertising']!
        : fields['description']!.replaceAll(
            '{days}',
            AffiliateAttribution.lifetime.inDays.toString(),
          );
    final icon = Icon(
      purpose.icon,
      size: context.sz(theme.sizes.iconLg),
      color: selected ? theme.colors.foreground : theme.colors.foregroundMuted,
    );
    return Padding(
      padding: EdgeInsets.symmetric(vertical: context.sp(theme.spacing.md)),
      child: managing && !essential
          ? UiSwitch(
              label: fields['title'],
              description: description,
              leading: icon,
              enabled: onChanged != null && !dependsOnAds,
              value: selected,
              onChanged: onChanged,
            )
          : Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                icon,
                UiGap.h(theme.spacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Wrap(
                        alignment: WrapAlignment.spaceBetween,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: context.sp(theme.spacing.sm),
                        runSpacing: context.sp(theme.spacing.xxs),
                        children: [
                          Text(
                            fields['title']!,
                            style: context.uiText.subheading.copyWith(
                              color: theme.colors.foreground,
                            ),
                          ),
                          UiBadge(
                            label:
                                copy[essential
                                    ? 'alwaysOn'
                                    : selected
                                    ? 'on'
                                    : 'off'],
                            variant: selected
                                ? UiBadgeVariant.soft
                                : UiBadgeVariant.outline,
                            intent: selected
                                ? UiIntent.primary
                                : UiIntent.neutral,
                            showDot: selected,
                          ),
                        ],
                      ),
                      Text(
                        description,
                        style: context.uiText.caption.copyWith(
                          color: theme.colors.foregroundMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}

class _CookieActions extends StatelessWidget {
  const _CookieActions({
    required this.copy,
    required this.managing,
    required this.busy,
    required this.onAccept,
    required this.onReject,
    required this.onManageOrSave,
  });
  final CookieNoticeContent copy;
  final bool managing, busy;
  final VoidCallback onAccept, onReject, onManageOrSave;

  @override
  Widget build(BuildContext context) {
    final spacing = context.ui.spacing;
    final mobile = context.uiRes.isMobile;
    final preference = UiButton(
      label: copy[managing ? 'save' : 'manage'],
      variant: managing ? UiVariant.primary : UiVariant.ghost,
      rounded: true,
      expand: mobile,
      alignment: mobile ? Alignment.center : null,
      size: UiSize.lg,
      loading: managing && busy,
      onPressed: busy ? null : onManageOrSave,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        UiDivider(spacing: spacing.sm),
        Wrap(
          alignment: mobile ? WrapAlignment.center : WrapAlignment.spaceBetween,
          spacing: context.sp(spacing.sm),
          runSpacing: context.sp(spacing.xs),
          children: [
            if (!mobile && !managing) preference,
            for (final (label, action) in [
              (copy['reject'], onReject),
              (copy['accept'], onAccept),
            ])
              UiButton(
                label: label,
                rounded: true,
                size: UiSize.lg,
                variant: UiVariant.outline,
                onPressed: busy ? null : action,
              ),
            if (mobile || managing) preference,
          ],
        ),
      ],
    );
  }
}
