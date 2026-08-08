import 'package:flutter/material.dart';

import '../../flutter-ui/flutter_ui.dart';
import '../cards/account_cards.dart';
import '../cards/community_cards.dart';
import '../models/app_models.dart';
import '../theme/app_tokens.dart';

/// Profile header: avatar, handle, tier, stats and primary actions.
class AppProfileHeaderBlock extends StatelessWidget {
  const AppProfileHeaderBlock({
    super.key,
    required this.trader,
    this.onFollow,
    this.onMessage,
    this.onEdit,
    this.isMe = false,
    this.featuredPosts,
  });

  final AppTrader trader;
  final VoidCallback? onFollow;
  final VoidCallback? onMessage;
  final VoidCallback? onEdit;
  final bool isMe;
  final List<AppPostCard>? featuredPosts;

  @override
  Widget build(BuildContext context) {
    final UiTheme theme = context.ui;
    final Widget actions = Wrap(
      spacing: context.sp(theme.spacing.sm),
      children: <Widget>[
        if (isMe)
          UiButton(
            label: 'Edit profile',
            variant: UiVariant.outline,
            size: UiSize.sm,
            expandOnMobile: false,
            onPressed: onEdit,
          )
        else ...<Widget>[
          UiButton(
            label: trader.isFollowing ? 'Following' : 'Follow',
            variant:
                trader.isFollowing ? UiVariant.outline : UiVariant.primary,
            size: UiSize.sm,
            expandOnMobile: false,
            onPressed: onFollow,
          ),
          UiButton(
            label: 'Message',
            variant: UiVariant.ghost,
            size: UiSize.sm,
            expandOnMobile: false,
            onPressed: onMessage,
          ),
        ],
      ],
    );

    return UiCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              UiAvatar(
                imageUrl: trader.avatarUrl,
                name: trader.displayName ?? trader.handle,
                size: UiSize.lg,
                verified: trader.verified,
              ),
              SizedBox(width: context.sp(theme.spacing.md)),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      trader.displayName ?? trader.handle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.uiText.heading,
                    ),
                    Text(
                      '@${trader.handle}',
                      style: context.uiText.caption
                          .copyWith(color: theme.colors.foregroundMuted),
                    ),
                    SizedBox(height: context.sp(theme.spacing.xs)),
                    UiBadge(
                      label: AppTokens.tierLabel(trader.tier),
                      intent: AppTokens.tierIntent(trader.tier),
                      icon: AppTokens.tierIcon(trader.tier),
                      filled: true,
                    ),
                  ],
                ),
              ),
              if (!context.uiRes.isMobile) actions,
            ],
          ),
          if (trader.bio != null) ...<Widget>[
            SizedBox(height: context.sp(theme.spacing.md)),
            Text(trader.bio!, style: context.uiText.body),
          ],
          SizedBox(height: context.sp(theme.spacing.md)),
          Row(
            children: <Widget>[
              _stat(context, uiCompactNumber(trader.followers), 'Followers'),
              _stat(context, uiCompactNumber(trader.following), 'Following'),
              if (trader.winRate != null)
                _stat(context, '${trader.winRate!.toStringAsFixed(0)}%',
                    'Win rate'),
            ],
          ),
          if (context.uiRes.isMobile) ...<Widget>[
            SizedBox(height: context.sp(theme.spacing.md)),
            actions,
          ],
        ],
      ),
    );
  }

  Widget _stat(BuildContext context, String value, String label) {
    final UiTheme theme = context.ui;
    return Padding(
      padding: EdgeInsets.only(right: context.sp(theme.spacing.xl)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(value, style: context.uiText.subheading),
          Text(
            label,
            style: context.uiText.caption
                .copyWith(color: theme.colors.foregroundMuted),
          ),
        ],
      ),
    );
  }
}

/// Pricing table — stacks on phones, side by side from tablet up.
class AppPricingBlock extends StatelessWidget {
  const AppPricingBlock({
    super.key,
    required this.plans,
    this.onSelect,
    this.title = 'Choose your plan',
  });

  final List<AppPlan> plans;
  final ValueChanged<AppPlan>? onSelect;
  final String title;

  @override
  Widget build(BuildContext context) {
    final UiTheme theme = context.ui;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(title, style: context.uiText.heading, textAlign: TextAlign.center),
        SizedBox(height: context.sp(theme.spacing.xl)),
        if (context.uiRes.isMobile)
          for (final AppPlan p in plans)
            Padding(
              padding: EdgeInsets.only(bottom: context.sp(theme.spacing.md)),
              child: AppPlanCard(
                plan: p,
                onSelect: onSelect == null ? null : () => onSelect!(p),
              ),
            )
        else
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                for (int i = 0; i < plans.length; i++) ...<Widget>[
                  Expanded(
                    child: AppPlanCard(
                      plan: plans[i],
                      onSelect: onSelect == null
                          ? null
                          : () => onSelect!(plans[i]),
                    ),
                  ),
                  if (i != plans.length - 1)
                    SizedBox(width: context.sp(theme.spacing.lg)),
                ],
              ],
            ),
          ),
      ],
    );
  }
}

/// Billing overview: current plan, renewal, usage meters.
class AppBillingBlock extends StatelessWidget {
  const AppBillingBlock({
    super.key,
    required this.tier,
    required this.renewalLabel,
    this.usage = const <Widget>[],
    this.onManage,
    this.onUpgrade,
  });

  final AppTier tier;
  final String renewalLabel;
  final List<Widget> usage;
  final VoidCallback? onManage;
  final VoidCallback? onUpgrade;

  @override
  Widget build(BuildContext context) {
    final UiTheme theme = context.ui;
    return UiCard(
      title: 'Subscription',
      accentColor: AppTokens.tierColor(context, tier),
      trailing: UiBadge(
        label: AppTokens.tierLabel(tier),
        intent: AppTokens.tierIntent(tier),
        filled: true,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            renewalLabel,
            style: context.uiText.caption
                .copyWith(color: theme.colors.foregroundMuted),
          ),
          if (usage.isNotEmpty) ...<Widget>[
            SizedBox(height: context.sp(theme.spacing.md)),
            for (final Widget u in usage)
              Padding(
                padding: EdgeInsets.only(bottom: context.sp(theme.spacing.sm)),
                child: u,
              ),
          ],
          SizedBox(height: context.sp(theme.spacing.md)),
          Row(
            children: <Widget>[
              Expanded(
                child: UiButton(
                  label: 'Manage billing',
                  variant: UiVariant.outline,
                  onPressed: onManage,
                ),
              ),
              SizedBox(width: context.sp(theme.spacing.sm)),
              Expanded(
                child: UiButton(label: 'Upgrade', onPressed: onUpgrade),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Settings section: titled group of setting rows.
class AppSettingsSectionBlock extends StatelessWidget {
  const AppSettingsSectionBlock({
    super.key,
    required this.title,
    required this.children,
    this.description,
  });

  final String title;
  final String? description;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final UiTheme theme = context.ui;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(title, style: context.uiText.subheading),
        if (description != null) ...<Widget>[
          SizedBox(height: context.sp(theme.spacing.xxs)),
          Text(
            description!,
            style: context.uiText.caption
                .copyWith(color: theme.colors.foregroundMuted),
          ),
        ],
        SizedBox(height: context.sp(theme.spacing.md)),
        for (final Widget c in children)
          Padding(
            padding: EdgeInsets.only(bottom: context.sp(theme.spacing.sm)),
            child: c,
          ),
      ],
    );
  }
}

/// Achievements wall.
class AppAchievementsBlock extends StatelessWidget {
  const AppAchievementsBlock({
    super.key,
    required this.achievements,
    this.title = 'Achievements',
  });

  final List<AppAchievement> achievements;
  final String title;

  @override
  Widget build(BuildContext context) {
    final UiTheme theme = context.ui;
    final int cols =
        context.uiRes.columns(mobile: 2, tablet: 3, desktop: 4, large: 5);
    return UiCard(
      title: title,
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        padding: EdgeInsets.zero,
        itemCount: achievements.length,
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: cols,
          mainAxisSpacing: context.sp(theme.spacing.md),
          crossAxisSpacing: context.sp(theme.spacing.md),
          childAspectRatio: 1.1,
        ),
        itemBuilder: (BuildContext _, int i) =>
            AppAchievementCard(achievement: achievements[i]),
      ),
    );
  }
}

/// Auth block: sign in / sign up form with social providers.
class AppAuthBlock extends StatelessWidget {
  const AppAuthBlock({
    super.key,
    required this.signUp,
    this.email,
    this.password,
    this.onEmailChanged,
    this.onPasswordChanged,
    this.onSubmit,
    this.onToggleMode,
    this.onGoogle,
    this.onApple,
    this.loading = false,
    this.error,
  });

  final bool signUp;
  final String? email;
  final String? password;
  final ValueChanged<String>? onEmailChanged;
  final ValueChanged<String>? onPasswordChanged;
  final VoidCallback? onSubmit;
  final VoidCallback? onToggleMode;
  final VoidCallback? onGoogle;
  final VoidCallback? onApple;
  final bool loading;
  final String? error;

  @override
  Widget build(BuildContext context) {
    final UiTheme theme = context.ui;
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: context.sz(420)),
      child: UiCard(
        elevated: true,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              signUp ? 'Create your account' : 'Welcome back',
              style: context.uiText.heading,
            ),
            SizedBox(height: context.sp(theme.spacing.lg)),
            if (error != null) ...<Widget>[
              UiCallout(
                title: error!,
                intent: UiIntent.bearish,
              ),
              SizedBox(height: context.sp(theme.spacing.md)),
            ],
            UiField(
              label: 'Email',
              child: UiInput(
                value: email,
                hintText: 'you@example.com',
                keyboardType: TextInputType.emailAddress,
                onChanged: onEmailChanged,
              ),
            ),
            SizedBox(height: context.sp(theme.spacing.md)),
            UiField(
              label: 'Password',
              child: UiInput(
                value: password,
                hintText: '••••••••',
                obscure: true,
                onChanged: onPasswordChanged,
              ),
            ),
            SizedBox(height: context.sp(theme.spacing.lg)),
            UiButton(
              label: signUp ? 'Create account' : 'Sign in',
              expand: true,
              loading: loading,
              onPressed: onSubmit,
            ),
            SizedBox(height: context.sp(theme.spacing.md)),
            UiDivider(label: 'or'),
            SizedBox(height: context.sp(theme.spacing.md)),
            UiButton(
              label: 'Continue with Google',
              variant: UiVariant.outline,
              leadingIcon: Icons.g_mobiledata,
              expand: true,
              onPressed: onGoogle,
            ),
            SizedBox(height: context.sp(theme.spacing.sm)),
            UiButton(
              label: 'Continue with Apple',
              variant: UiVariant.outline,
              leadingIcon: Icons.apple,
              expand: true,
              onPressed: onApple,
            ),
            SizedBox(height: context.sp(theme.spacing.md)),
            UiButton(
              label: signUp
                  ? 'Already have an account? Sign in'
                  : 'New here? Create an account',
              variant: UiVariant.ghost,
              expand: true,
              onPressed: onToggleMode,
            ),
          ],
        ),
      ),
    );
  }
}

/// Onboarding step list with progress.
class AppOnboardingBlock extends StatelessWidget {
  const AppOnboardingBlock({
    super.key,
    required this.steps,
    required this.currentStep,
    this.onContinue,
    this.onSkip,
  });

  final List<AppChecklistItem> steps;
  final int currentStep;
  final VoidCallback? onContinue;
  final VoidCallback? onSkip;

  @override
  Widget build(BuildContext context) {
    final UiTheme theme = context.ui;
    return UiCard(
      title: 'Get set up',
      subtitle: 'Step ${currentStep + 1} of ${steps.length}',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          UiProgressBar(
            value: steps.isEmpty ? 0 : (currentStep + 1) / steps.length,
            showValue: false,
          ),
          SizedBox(height: context.sp(theme.spacing.lg)),
          for (int i = 0; i < steps.length; i++)
            Padding(
              padding: EdgeInsets.only(bottom: context.sp(theme.spacing.md)),
              child: Row(
                children: <Widget>[
                  Icon(
                    steps[i].done
                        ? Icons.check_circle
                        : (i == currentStep
                            ? Icons.radio_button_checked
                            : Icons.radio_button_unchecked),
                    size: context.sz(theme.sizes.iconSm),
                    color: steps[i].done
                        ? theme.colors.bullish
                        : (i == currentStep
                            ? theme.colors.primary
                            : theme.colors.foregroundSubtle),
                  ),
                  SizedBox(width: context.sp(theme.spacing.sm)),
                  Expanded(
                    child: Text(steps[i].label, style: context.uiText.body),
                  ),
                ],
              ),
            ),
          Row(
            children: <Widget>[
              Expanded(
                child: UiButton(
                  label: 'Skip',
                  variant: UiVariant.ghost,
                  onPressed: onSkip,
                ),
              ),
              SizedBox(width: context.sp(theme.spacing.sm)),
              Expanded(
                child: UiButton(label: 'Continue', onPressed: onContinue),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
