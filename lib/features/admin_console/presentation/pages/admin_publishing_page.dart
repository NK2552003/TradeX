import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:tradex/core/app-ui/app_ui.dart';
import 'package:tradex/core/config/supabase_config.dart';
import 'package:tradex/core/flutter-ui/flutter_ui.dart';
import 'package:tradex/features/auth/models/pricing_models.dart';

/// Admin-only catalogue publishing and community review, backed by RLS.
class AdminPublishingPage extends StatefulWidget {
  const AdminPublishingPage({super.key});

  @override
  State<AdminPublishingPage> createState() => _AdminPublishingPageState();
}

class _AdminPublishingPageState extends State<AdminPublishingPage> {
  Map<String, dynamic>? _catalogue;
  List<Map<String, dynamic>> _pending = const [];
  List<Map<String, dynamic>> _pendingComments = const [];
  final Map<String, TextEditingController> _monthly = {};
  final Map<String, TextEditingController> _annual = {};
  final Map<String, TextEditingController> _subtitle = {};
  final Map<String, TextEditingController> _limits = {};
  final Map<String, TextEditingController> _reviewNotes = {};
  bool _loading = true;
  bool _saving = false;
  String? _error;

  SupabaseClient get _client => SupabaseConfig.client!;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final controller in [
      ..._monthly.values,
      ..._annual.values,
      ..._subtitle.values,
      ..._limits.values,
      ..._reviewNotes.values,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    if (!SupabaseConfig.isConfigured) {
      setState(() {
        _loading = false;
        _error = 'Connect Supabase to manage publishing.';
      });
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final row = await _client
          .from('pricing_catalogues')
          .select('catalogue')
          .eq('id', 'default')
          .maybeSingle();
      final pending = await _client
          .from('community_posts')
          .select('id,author_id,body,created_at,moderation_status')
          .eq('moderation_status', 'pending')
          .order('created_at', ascending: true);
      final pendingComments = await _client
          .from('community_comments')
          .select('id,post_id,author_id,body,created_at,moderation_status')
          .eq('moderation_status', 'pending')
          .order('created_at', ascending: true);
      if (!mounted) return;
      final raw = row?['catalogue'];
      final catalogue = raw is Map ? Map<String, dynamic>.from(raw) : null;
      for (final controller in [
        ..._monthly.values,
        ..._annual.values,
        ..._subtitle.values,
        ..._limits.values,
      ]) {
        controller.dispose();
      }
      _monthly.clear();
      _annual.clear();
      _subtitle.clear();
      _limits.clear();
      if (catalogue != null) {
        for (final rawPlan in catalogue['plans'] as List) {
          final plan = PricingPlanModel.fromJson(
            Map<String, dynamic>.from(rawPlan as Map),
          );
          _monthly[plan.id] = TextEditingController(
            text: plan.monthlyAmount.toStringAsFixed(0),
          );
          _annual[plan.id] = TextEditingController(
            text: plan.annualMonthlyAmount.toStringAsFixed(0),
          );
          _subtitle[plan.id] = TextEditingController(text: plan.subtitle);
          final limitValues = Map<String, dynamic>.from(
            rawPlan['limits'] as Map,
          );
          for (final key in [
            'notes',
            'trades',
            'live_playbooks',
            'ai_queries_per_month',
          ]) {
            _limits['${plan.id}:$key'] = TextEditingController(
              text: '${limitValues[key]}',
            );
          }
        }
      }
      setState(() {
        _catalogue = catalogue;
        _pending = [
          for (final item in pending) Map<String, dynamic>.from(item),
        ];
        _pendingComments = [
          for (final item in pendingComments) Map<String, dynamic>.from(item),
        ];
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Unable to load publishing controls: $error';
      });
    }
  }

  Future<void> _savePricing() async {
    if (_catalogue == null || _saving) return;
    setState(() => _saving = true);
    try {
      final draft = jsonDecode(jsonEncode(_catalogue)) as Map<String, dynamic>;
      for (final rawPlan in draft['plans'] as List) {
        final plan = rawPlan as Map<String, dynamic>;
        final id = plan['id'] as String;
        final monthly = double.tryParse(_monthly[id]!.text.trim());
        final annual = double.tryParse(_annual[id]!.text.trim());
        if (monthly == null ||
            annual == null ||
            !monthly.isFinite ||
            !annual.isFinite ||
            monthly < 0 ||
            annual < 0 ||
            annual > monthly) {
          throw FormatException(
            'Enter valid monthly and annual prices for $id.',
          );
        }
        if (plan['tier'] == 'free' && (monthly != 0 || annual != 0)) {
          throw const FormatException('The Free plan must remain free.');
        }
        plan['monthly_amount'] = monthly;
        plan['annual_monthly_amount'] = annual;
        plan['subtitle'] = _subtitle[id]!.text.trim();
        final limits = <String, int>{};
        for (final key in [
          'notes',
          'trades',
          'live_playbooks',
          'ai_queries_per_month',
        ]) {
          final value = int.tryParse(_limits['$id:$key']!.text.trim());
          if (value == null || value < 1) {
            throw FormatException('Enter a positive $key limit for $id.');
          }
          limits[key] = value;
        }
        plan['limits'] = limits;
        plan['features_summary'] = [
          'Up to ${limits['notes']} research notes',
          'Up to ${limits['trades']} logged trades (total)',
          'Up to ${limits['live_playbooks']} active playbooks',
          'Up to ${limits['ai_queries_per_month']} AI prompts per month',
          'Charts, market browsing and community features where available',
          if (plan['tier'] != 'free')
            'Paid activation pending verified checkout',
        ];
        // Checkout cannot be published from an editorial control.
        plan['is_purchasable'] = plan['tier'] == 'free';
      }
      for (final rawCategory in draft['categories'] as List) {
        for (final rawRow in (rawCategory as Map)['rows'] as List) {
          final row = rawRow as Map;
          final limitKey = switch (row['id']) {
            'feat_notes' => 'notes',
            'feat_trades' => 'trades',
            'feat_playbooks' => 'live_playbooks',
            'feat_ai' => 'ai_queries_per_month',
            _ => null,
          };
          if (limitKey == null) continue;
          for (final rawPlan in draft['plans'] as List) {
            final plan = rawPlan as Map;
            final column = switch (plan['tier']) {
              'free' => 'free_value',
              'premium' => 'pro_value',
              _ => 'enterprise_value',
            };
            final value = (plan['limits'] as Map)[limitKey];
            final suffix = limitKey == 'ai_queries_per_month'
                ? '/ month'
                : limitKey == 'live_playbooks'
                ? 'active'
                : 'total';
            row[column] = '$value $suffix';
          }
        }
      }
      await _client.from('pricing_catalogues').upsert({
        'id': 'default',
        'catalogue': draft,
        'published': true,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }, onConflict: 'id');
      if (!mounted) return;
      UiToast.success(context, title: 'Pricing published');
      await _load();
    } catch (error) {
      if (mounted) {
        UiToast.error(context, title: 'Publish failed', message: '$error');
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _publishStarterCatalogue() async {
    setState(() => _saving = true);
    try {
      final source = await rootBundle.loadString(
        'assets/data/pricing_catalogue.json',
      );
      final catalogue = jsonDecode(source) as Map<String, dynamic>;
      await _client.from('pricing_catalogues').upsert({
        'id': 'default',
        'catalogue': catalogue,
        'published': true,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }, onConflict: 'id');
      if (!mounted) return;
      UiToast.success(context, title: 'Starter pricing published');
      await _load();
    } catch (error) {
      if (mounted) {
        UiToast.error(context, title: 'Publish failed', message: '$error');
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _review(
    String id,
    bool approve, {
    bool isComment = false,
  }) async {
    setState(() => _saving = true);
    try {
      final note = _reviewNotes[id]?.text.trim() ?? '';
      if (!approve && note.isEmpty) {
        throw StateError('Enter a reason before rejecting this post.');
      }
      await _client
          .from(isComment ? 'community_comments' : 'community_posts')
          .update({
            'moderation_status': approve ? 'approved' : 'rejected',
            'moderation_note': approve ? null : note,
          })
          .eq('id', id)
          .eq('moderation_status', 'pending')
          .select('id')
          .single();
      if (!mounted) return;
      UiToast.success(
        context,
        title:
            '${isComment ? 'Comment' : 'Post'} ${approve ? 'approved' : 'rejected'}',
      );
      await _load();
    } catch (error) {
      if (mounted) {
        UiToast.error(context, title: 'Review failed', message: '$error');
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.ui;
    return UiPage(
      title: 'Publishing & reviews',
      subtitle: 'Published subscription catalogue and pending community posts',
      actions: [UiButton(label: 'Refresh', onPressed: _load)],
      child: _loading
          ? const UiSkeleton(width: 300, height: 160)
          : _error != null
          ? UiEmptyState(
              title: 'Publishing unavailable',
              message: _error,
              actionLabel: 'Retry',
              onActionPressed: _load,
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                UiCard(
                  title: 'Subscription catalogue',
                  child: _catalogue == null
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const UiCallout(
                              title: 'No catalogue row',
                              message:
                                  'Publish the reviewed starter catalogue to make pricing available.',
                              intent: UiIntent.warning,
                            ),
                            UiGap.v(theme.spacing.sm),
                            UiButton(
                              label: 'Publish starter catalogue',
                              loading: _saving,
                              onPressed: _publishStarterCatalogue,
                            ),
                          ],
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const UiCallout(
                              title: 'Paid checkout unavailable',
                              message:
                                  'Publishing text and prices does not enable paid activation.',
                              intent: UiIntent.info,
                            ),
                            for (final raw in _catalogue!['plans'] as List) ...[
                              UiGap.v(theme.spacing.md),
                              _planEditor(
                                Map<String, dynamic>.from(raw as Map),
                              ),
                            ],
                            UiGap.v(theme.spacing.md),
                            UiButton(
                              label: 'Publish catalogue',
                              loading: _saving,
                              onPressed: _savePricing,
                            ),
                          ],
                        ),
                ),
                UiGap.v(theme.spacing.lg),
                UiCard(
                  title: 'Comment approval queue (${_pendingComments.length})',
                  child: _pendingComments.isEmpty
                      ? const UiEmptyState(
                          title: 'No comments waiting for review',
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            for (final comment in _pendingComments) ...[
                              _postReview(comment, isComment: true),
                              UiGap.v(theme.spacing.md),
                            ],
                          ],
                        ),
                ),
                UiGap.v(theme.spacing.lg),
                UiCard(
                  title: 'Community approval queue (${_pending.length})',
                  child: _pending.isEmpty
                      ? const UiEmptyState(title: 'No posts waiting for review')
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            for (final post in _pending) ...[
                              _postReview(post),
                              UiGap.v(theme.spacing.md),
                            ],
                          ],
                        ),
                ),
              ],
            ),
    );
  }

  Widget _planEditor(Map<String, dynamic> raw) {
    final plan = PricingPlanModel.fromJson(raw);
    return UiCard(
      title: plan.name,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          UiInput(
            label: 'Monthly INR',
            controller: _monthly[plan.id],
            keyboardType: TextInputType.number,
          ),
          UiGap.v(context.ui.spacing.sm),
          UiInput(
            label: 'Annual monthly equivalent INR',
            controller: _annual[plan.id],
            keyboardType: TextInputType.number,
          ),
          UiGap.v(context.ui.spacing.sm),
          UiInput.multiline(
            label: 'Availability and plan description',
            controller: _subtitle[plan.id],
          ),
          UiGap.v(context.ui.spacing.sm),
          for (final key in [
            'notes',
            'trades',
            'live_playbooks',
            'ai_queries_per_month',
          ]) ...[
            UiInput(
              label: key.replaceAll('_', ' '),
              controller: _limits['${plan.id}:$key'],
              keyboardType: TextInputType.number,
            ),
            UiGap.v(context.ui.spacing.sm),
          ],
          for (final feature in plan.featuresSummary)
            Text('• $feature', style: context.uiText.caption),
        ],
      ),
    );
  }

  Widget _postReview(Map<String, dynamic> post, {bool isComment = false}) {
    final id = post['id'].toString();
    final controller = _reviewNotes.putIfAbsent(
      id,
      () => TextEditingController(),
    );
    return UiCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(post['body']?.toString() ?? '', style: context.uiText.body),
          UiGap.v(context.ui.spacing.xs),
          Text(
            'Author ${post['author_id']} · ${post['created_at']}',
            style: context.uiText.caption,
          ),
          UiGap.v(context.ui.spacing.sm),
          UiInput(label: 'Rejection reason', controller: controller),
          UiGap.v(context.ui.spacing.sm),
          Wrap(
            spacing: context.sp(context.ui.spacing.sm),
            children: [
              UiButton(
                label: 'Approve',
                loading: _saving,
                onPressed: _saving
                    ? null
                    : () => _review(id, true, isComment: isComment),
              ),
              UiButton(
                label: 'Reject',
                variant: UiVariant.outline,
                loading: _saving,
                onPressed: _saving
                    ? null
                    : () => _review(id, false, isComment: isComment),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
