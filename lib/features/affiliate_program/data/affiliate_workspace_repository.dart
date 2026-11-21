import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:alphajournal/core/config/customer_data_policy.dart';
import 'package:alphajournal/core/config/supabase_config.dart';
import 'package:alphajournal/features/affiliate_program/models/affiliate_workspace.dart';

class AffiliateWorkspaceRepository {
  AffiliateWorkspaceRepository({this.demoOverride});

  static final AffiliateWorkspaceRepository instance =
      AffiliateWorkspaceRepository(demoOverride: true);
  static const _storageKey = 'alphajournal_affiliate_workspace_v2_inr';
  static Future<void>? _activeWrite;
  final bool? demoOverride;

  SupabaseClient? get _db {
    if (!SupabaseConfig.isConfigured) return null;
    try {
      return SupabaseConfig.client;
    } catch (_) {
      return null;
    }
  }

  bool get _allowDemo => demoOverride ?? CustomerDataPolicy.allowDemo;

  Future<T> _serialize<T>(Future<T> Function() action) {
    final prev = _activeWrite;
    final next = prev == null
        ? Future<T>.sync(action)
        : prev.then((_) => action());
    late final Future<void> current;
    current = next.then<void>(
      (_) {
        if (identical(_activeWrite, current)) _activeWrite = null;
      },
      onError: (_) {
        if (identical(_activeWrite, current)) _activeWrite = null;
      },
    );
    _activeWrite = current;
    return next;
  }

  static bool _loggedRpcMissing = false;

  Future<AffiliateWorkspace> load() async {
    final db = _db;
    if (db != null) {
      String? userId = db.auth.currentUser?.id;
      try {
        try {
          final raw = await db.rpc('affiliate_workspace');
          if (raw is Map && raw['profile'] is Map) {
            final Map<String, Object?> payload = raw.map(
              (k, v) => MapEntry(k.toString(), v),
            );
            payload['tiers'] ??= _defaultTiers();
            payload['terms'] ??= _defaultTerms();
            return AffiliateWorkspace.fromJson(payload);
          }
        } catch (_) {
          // Fall through to assemble from live tables
        }

        Map<String, dynamic>? profileRes;
        if (userId != null) {
          profileRes = await db
              .from('profiles')
              .select('id, referral_code, handle, display_name')
              .eq('id', userId)
              .maybeSingle();
        } else {
          profileRes = await db
              .from('profiles')
              .select('id, referral_code, handle, display_name')
              .order('created_at', ascending: false)
              .limit(1)
              .maybeSingle();
          userId = profileRes?['id']?.toString();
        }

        if (userId != null) {
          final affProfRes = await db
              .from('affiliate_profiles')
              .select(
                'id, total_earnings, unpaid_balance, paid_earnings, tier, '
                'commission_rate, payout_method, payout_details, '
                'paid_referrals_count, complimentary_pro_unlocked, '
                'terms_version_accepted, status',
              )
              .eq('id', userId)
              .maybeSingle()
              .catchError((_) => null);

          final referralsRes = await db
              .from('affiliate_referrals')
              .select('*')
              .eq('affiliate_id', userId)
              .limit(100)
              .catchError((_) => <dynamic>[]);

          final payoutsRes = await db
              .from('affiliate_payouts')
              .select('*')
              .eq('affiliate_id', userId)
              .order('created_at', ascending: false)
              .limit(50)
              .catchError((_) => <dynamic>[]);

          final userRefCode =
              profileRes?['referral_code']?.toString() ??
              'REF-${userId.substring(0, 8).toUpperCase()}';
          final handle = (profileRes?['handle']?.toString() ?? 'trader')
              .replaceAll('@', '');
          final displayName = profileRes?['display_name']?.toString() ?? handle;

          final double earnings =
              (affProfRes?['total_earnings'] as num?)?.toDouble() ?? 0.0;
          final double unpaid =
              (affProfRes?['unpaid_balance'] as num?)?.toDouble() ?? 0.0;
          final double paid =
              (affProfRes?['paid_earnings'] as num?)?.toDouble() ?? 0.0;
          final int paidReferralsCount =
              (affProfRes?['paid_referrals_count'] as num?)?.toInt() ??
              ((referralsRes as List?)
                      ?.where(
                        (dynamic r) => r is Map && r['status'] == 'converted',
                      )
                      .length ??
                  0);
          final bool complimentaryProUnlocked =
              affProfRes?['complimentary_pro_unlocked'] == true ||
              (affProfRes?['status']?.toString() == 'active' &&
                  paidReferralsCount >= 50);
          final String tier = paidReferralsCount >= 50
              ? 'milestone'
              : 'starter';
          final double commissionRate =
              (affProfRes?['commission_rate'] as num?)?.toDouble() ?? 0.0;

          final Map<String, Object?> liveProfile = <String, Object?>{
            'id': userId,
            'affiliate_code': userRefCode,
            'custom_slug': handle,
            'display_name': displayName,
            'tier': tier,
            'commission_rate': commissionRate,
            'current_commission_inr': paidReferralsCount >= 50 ? 30.0 : 10.0,
            'paid_referrals_count': paidReferralsCount,
            'free_pro_threshold': 50,
            'complimentary_pro_unlocked': complimentaryProUnlocked,
            'terms_version_accepted':
                affProfRes?['terms_version_accepted']?.toString() ??
                '2026.2-INR',
            'tds_rate': 0.05,
            'currency': 'INR',
            'total_referrals': (referralsRes as List?)?.length ?? 0,
            'active_referrals': paidReferralsCount,
            'total_earnings': earnings,
            'unpaid_balance': unpaid,
            'paid_earnings': paid,
            'payout_method': affProfRes?['payout_method'] ?? 'upi',
            'payout_details':
                affProfRes?['payout_details'] ??
                <String, Object?>{
                  'upi_id': '$handle@okhdfcbank',
                  'payout_account': '$handle@okhdfcbank',
                },
            'minimum_payout_threshold': 1000.0,
            'auto_payout_enabled': true,
            'status': affProfRes?['status']?.toString() ?? 'active',
          };

          final List<Map<String, Object?>> liveReferrals =
              (referralsRes as List? ?? const <dynamic>[])
                  .map(
                    (dynamic r) => r is Map
                        ? r.map(
                            (dynamic k, dynamic v) => MapEntry(k.toString(), v),
                          )
                        : <String, Object?>{},
                  )
                  .toList();

          final List<Map<String, Object?>> livePayouts =
              (payoutsRes as List? ?? const <dynamic>[])
                  .map(
                    (dynamic p) => p is Map
                        ? p.map(
                            (dynamic k, dynamic v) => MapEntry(k.toString(), v),
                          )
                        : <String, Object?>{},
                  )
                  .toList();

          return AffiliateWorkspace.fromJson(<String, Object?>{
            'profile': liveProfile,
            'campaigns': const <Map<String, Object?>>[],
            'referrals': liveReferrals,
            'payouts': livePayouts,
            'assets': _defaultAssets(userRefCode, handle),
            'tiers': _defaultTiers(),
            'terms': _defaultTerms(),
          });
        }
      } catch (e) {
        if (!_loggedRpcMissing) {
          _loggedRpcMissing = true;
          debugPrint(
            '[AffiliateWorkspaceRepository.load] Remote assembly fallback: $e',
          );
        }
      }
    }
    if (!_allowDemo) {
      return AffiliateWorkspace.fromJson(<String, Object?>{
        'tiers': _defaultTiers(),
        'terms': _defaultTerms(),
      });
    }
    return AffiliateWorkspace.fromJson(await _loadDemoMap(), isPreview: true);
  }

  static List<Map<String, Object?>> _defaultAssets(
    String code,
    String slug,
  ) => [
    {
      'id': 'ast-1',
      'title': 'AlphaJournal Journal & Community Promotion Card',
      'category': 'banner_social',
      'headline': 'Level Up Your Trading with AlphaJournal Journal',
      'body':
          'Track your trades, analyze win rates, and share setups with India\'s elite trading community.',
      'call_to_action': 'Start Free on AlphaJournal',
      'landing_path': '/r/$code',
      'tags': ['Social', 'Banner', 'Instagram', 'Twitter'],
      'published': true,
    },
    {
      'id': 'ast-2',
      'title': 'Direct Creator Referral Link',
      'category': 'link_custom',
      'headline': 'Month 1 Offer: Basic ₹239 · Pro ₹399 (Monthly Plans)',
      'body':
          'New subscribers get Month 1 at ₹239 (Basic) or ₹399 (Pro) on monthly plans, then regular ₹299/₹499 renewal (1 use per user).',
      'call_to_action': 'Claim Month 1 Partner Offer',
      'landing_path': '/r/$slug',
      'tags': ['Link', 'CustomSlug', 'Month1Offer'],
      'published': true,
    },
  ];

  Future<void> createCampaign(String name, String channel, String slug) async {
    final cleanName = name.trim();
    final cleanSlug = slug.trim().toLowerCase();
    const channels = {'youtube', 'newsletter', 'instagram', 'website', 'other'};
    if (cleanName.isEmpty ||
        cleanName.length > 80 ||
        !channels.contains(channel) ||
        !affiliateCampaignSlugPattern.hasMatch(cleanSlug)) {
      throw ArgumentError(
        'Enter a campaign name and a lowercase slug (3–40 letters, numbers or hyphens).',
      );
    }
    final db = _db;
    if (db != null) {
      await db.from('affiliate_campaigns').insert({
        'affiliate_id': db.auth.currentUser!.id,
        'name': cleanName,
        'channel': channel,
        'slug': cleanSlug,
      });
      return;
    }
    if (!_allowDemo) throw StateError('Sign in required.');
    await _serialize(() async {
      final map = await _loadDemoMap();
      final campaigns = (map['campaigns']! as List)
          .cast<Map<String, Object?>>();
      if (campaigns.any((c) => c['slug'] == cleanSlug)) {
        throw StateError('That campaign slug is already in use.');
      }
      campaigns.add(<String, Object?>{
        'id': 'cmp-${DateTime.now().microsecondsSinceEpoch}',
        'name': cleanName,
        'slug': cleanSlug,
        'channel': channel,
        'status': 'active',
        'clicks': 0,
        'conversions_count': 0,
        'revenue_generated_inr': 0.0,
        'created_at': DateTime.now().toUtc().toIso8601String(),
      });
      await _saveDemoMap(map);
    });
  }

  Future<void> setCampaignStatus(String id, bool active) async {
    final status = active ? 'active' : 'paused';
    final db = _db;
    if (db != null) {
      await db
          .from('affiliate_campaigns')
          .update({'status': status})
          .eq('id', id);
      return;
    }
    if (!_allowDemo) throw StateError('Sign in required.');
    await _serialize(() async {
      final map = await _loadDemoMap();
      for (final row
          in (map['campaigns']! as List).cast<Map<String, Object?>>()) {
        if (row['id'] == id) row['status'] = status;
      }
      await _saveDemoMap(map);
    });
  }

  Future<void> deleteCampaign(String id) async {
    final db = _db;
    if (db != null) {
      await db.from('affiliate_campaigns').delete().eq('id', id);
      return;
    }
    if (!_allowDemo) throw StateError('Sign in required.');
    await _serialize(() async {
      final map = await _loadDemoMap();
      final campaigns = (map['campaigns']! as List)
          .cast<Map<String, Object?>>();
      campaigns.removeWhere((c) => c['id'] == id);
      await _saveDemoMap(map);
    });
  }

  Future<void> requestPayout(double amount) async {
    if (!amount.isFinite || (amount * 100).roundToDouble() != amount * 100) {
      throw ArgumentError('Enter a valid INR amount with up to two decimals.');
    }
    final db = _db;
    if (db != null) {
      try {
        await db.rpc('request_affiliate_payout', params: {'p_amount': amount});
        return;
      } catch (e) {
        debugPrint(
          '[AffiliateWorkspaceRepository.requestPayout] rpc error, trying direct insert: $e',
        );
        try {
          final user = db.auth.currentUser;
          if (user != null) {
            await db.from('affiliate_payouts').insert({
              'affiliate_id': user.id,
              'amount': amount,
              'currency': 'INR',
              'status': 'pending',
              'payout_method': 'upi',
              'notes': 'Requested from AlphaJournal Partner Portal',
            });
            return;
          }
        } catch (insertErr) {
          debugPrint(
            '[AffiliateWorkspaceRepository.requestPayout] direct insert error: $insertErr',
          );
        }
      }
    }
    if (!_allowDemo) throw StateError('Sign in required.');
    await _serialize(() async {
      final map = await _loadDemoMap();
      final profile = map['profile']! as Map<String, Object?>;
      final payouts = (map['payouts']! as List).cast<Map<String, Object?>>();
      final min = ((profile['minimum_payout_threshold'] as num?) ?? 1000)
          .toDouble();
      final balance = ((profile['unpaid_balance'] as num?) ?? 0).toDouble();
      final tdsRate = ((profile['tds_rate'] as num?) ?? 0.05).toDouble();
      final gstRegistered = profile['gst_registered'] == true;
      final details = profile['payout_details'] is Map
          ? Map<String, Object?>.from(profile['payout_details']! as Map)
          : <String, Object?>{};
      final account =
          details['payout_account']?.toString().trim() ??
          details['upi_id']?.toString().trim() ??
          details['account_number']?.toString().trim() ??
          '';
      if (account.isEmpty) {
        throw StateError(
          'Save an Indian UPI or Bank payout destination first.',
        );
      }
      if (payouts.any(
        (p) => p['status'] == 'pending' || p['status'] == 'processing',
      )) {
        throw StateError('A payout request is already in progress.');
      }
      if (amount < 1000 || amount < min || amount > balance) {
        throw StateError(
          'Enter an amount between ₹${min.toStringAsFixed(0)} and ₹${balance.toStringAsFixed(2)}.',
        );
      }
      final double tdsAmount = double.parse(
        (amount * tdsRate).toStringAsFixed(2),
      );
      final double gstAmount = gstRegistered
          ? double.parse((amount * 0.18).toStringAsFixed(2))
          : 0.0;
      final double netAmount = double.parse(
        (amount - tdsAmount + gstAmount).toStringAsFixed(2),
      );
      profile['unpaid_balance'] = balance - amount;
      payouts.insert(0, {
        'id': 'pay-${DateTime.now().microsecondsSinceEpoch}',
        'amount': amount,
        'gross_amount_inr': amount,
        'tds_amount_inr': tdsAmount,
        'gst_amount_inr': gstAmount,
        'net_amount_inr': netAmount,
        'currency': 'INR',
        'status': 'pending',
        'payout_method': profile['payout_method'] ?? 'upi',
        'payout_destination': details,
        'balance_reserved': true,
        'created_at': DateTime.now().toUtc().toIso8601String(),
      });
      await _saveDemoMap(map);
    });
  }

  /// Admin action to settle, mark processing, or reject/refund a partner payout in INR.
  Future<void> adminReviewPayout({
    required String payoutId,
    required String status,
    String? transactionReference,
    String? notes,
  }) async {
    final db = _db;
    if (db != null) {
      try {
        await db.rpc(
          'admin_review_affiliate_payout',
          params: {
            'p_payout_id': payoutId,
            'p_status': status,
            'p_transaction_reference': transactionReference,
            'p_notes': notes,
          },
        );
        return;
      } catch (e) {
        debugPrint(
          '[AffiliateWorkspaceRepository.adminReviewPayout] rpc error, falling back: $e',
        );
      }
    }
    if (!_allowDemo) throw StateError('Sign in required.');
    await _serialize(() async {
      final map = await _loadDemoMap();
      final profile = map['profile']! as Map<String, Object?>;
      final payouts = (map['payouts']! as List).cast<Map<String, Object?>>();
      for (final row in payouts) {
        if (row['id'] == payoutId) {
          final String oldStatus = row['status']?.toString() ?? 'pending';
          if (oldStatus != 'pending' && oldStatus != 'processing') {
            throw StateError('Payout has already been settled.');
          }
          final double amount = ((row['amount'] as num?) ?? 0).toDouble();
          row['status'] = status;
          if (transactionReference != null &&
              transactionReference.trim().isNotEmpty) {
            row['transaction_reference'] = transactionReference.trim();
          }
          if (notes != null && notes.trim().isNotEmpty) {
            row['notes'] = notes.trim();
          }
          row['processed_at'] = DateTime.now().toUtc().toIso8601String();
          if (status == 'paid') {
            final double paid = ((profile['paid_earnings'] as num?) ?? 0)
                .toDouble();
            profile['paid_earnings'] = paid + amount;
          } else if (status == 'failed' || status == 'cancelled') {
            final double unpaid = ((profile['unpaid_balance'] as num?) ?? 0)
                .toDouble();
            profile['unpaid_balance'] = unpaid + amount;
          }
          break;
        }
      }
      await _saveDemoMap(map);
    });
  }

  /// Admin action to update a partner's tier and recurring INR commission rate.
  Future<void> adminUpdatePartnerTier({
    String? tierCode,
    String? tierId,
    double? commissionRate,
  }) async {
    final String effectiveTier = tierCode ?? tierId ?? 'standard';
    final double effectiveRate = commissionRate ?? 0.25;
    final db = _db;
    if (db != null) {
      await db
          .from('affiliate_profiles')
          .update({
            'tier': effectiveTier,
            'commission_rate': effectiveRate,
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('id', db.auth.currentUser!.id);
      return;
    }
    if (!_allowDemo) throw StateError('Sign in required.');
    await _serialize(() async {
      final map = await _loadDemoMap();
      final profile = map['profile']! as Map<String, Object?>;
      profile['tier'] = effectiveTier;
      profile['commission_rate'] = effectiveRate;
      await _saveDemoMap(map);
    });
  }

  /// Admin action to publish a new creator marketing asset to the partner workspace.
  Future<void> adminPublishMarketingAsset({
    required String title,
    String? format,
    String? category,
    String? badge,
    required String body,
  }) async {
    final String effectiveFormat = (format ?? category ?? badge ?? 'Social')
        .trim();
    final db = _db;
    if (db != null) {
      await db.from('affiliate_assets').insert({
        'title': title.trim(),
        'format': effectiveFormat,
        'body': body.trim(),
        'published': true,
      });
      return;
    }
    if (!_allowDemo) throw StateError('Sign in required.');
    await _serialize(() async {
      final map = await _loadDemoMap();
      final assets = (map['assets']! as List).cast<Map<String, Object?>>();
      assets.add({
        'id': 'ast-${DateTime.now().microsecondsSinceEpoch}',
        'title': title.trim(),
        'format': effectiveFormat,
        'body': body.trim(),
        'published': true,
      });
      await _saveDemoMap(map);
    });
  }

  Future<void> updateProfile(Map<String, Object?> patch) async {
    final db = _db;
    if (db != null) {
      await db
          .from('affiliate_profiles')
          .update(patch)
          .eq('id', db.auth.currentUser!.id);
      return;
    }
    if (!_allowDemo) throw StateError('Sign in required.');
    await _serialize(() async {
      final map = await _loadDemoMap();
      final profile = map['profile']! as Map<String, Object?>;
      for (final entry in patch.entries) {
        if (entry.key == 'payout_details' &&
            entry.value is Map &&
            profile['payout_details'] is Map) {
          final merged = Map<String, Object?>.from(
            profile['payout_details']! as Map,
          );
          for (final sub in (entry.value! as Map).entries) {
            merged[sub.key.toString()] = sub.value;
          }
          profile['payout_details'] = merged;
        } else {
          profile[entry.key] = entry.value;
        }
      }
      await _saveDemoMap(map);
    });
  }

  Future<Map<String, Object?>> _loadDemoMap() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);
    if (raw != null) {
      final decoded = (jsonDecode(raw) as Map).map(
        (k, v) => MapEntry(k.toString(), v),
      );
      decoded['tiers'] ??= _defaultTiers();
      decoded['terms'] ??= _defaultTerms();
      return decoded;
    }
    final seedRaw = jsonEncode(_demo());
    await prefs.setString(_storageKey, seedRaw);
    return (jsonDecode(seedRaw) as Map).map(
      (k, v) => MapEntry(k.toString(), v),
    );
  }

  Future<void> _saveDemoMap(Map<String, Object?> map) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_storageKey, jsonEncode(map));
  }

  static List<Map<String, Object?>> _defaultTiers() => [
    {
      'tier_code': 'starter',
      'display_name': 'Tier 1 · Starter Partner (1–50 Paid Users)',
      'commission_rate': 0.0,
      'payout_per_user_inr': 10,
      'min_active_referrals': 0,
      'min_monthly_volume_inr': 0,
      'min_payout_threshold_inr': 1000,
      'tds_rate': 0.05,
      'settlement_cycle': 'UPI / Bank NEFT (Min ₹1,000)',
      'perks': [
        '₹10 INR payout per verified paid Basic (₹299/mo) or Pro (₹499/mo) user for your first 50 paid conversions',
        'Referred monthly subscribers get Month 1 at ₹239 (Basic) or ₹399 (Pro), then regular ₹299/₹499 renewal (1 per user)',
        'Custom referral slug, UTM campaign tracking, and SEBI/ASCI compliant kit',
        'No complimentary Basic/Pro tier before reaching 50 verified paid referrals',
      ],
      'sort_order': 1,
    },
    {
      'tier_code': 'milestone',
      'display_name': 'Tier 2 · 50+ Milestone Partner (51+ Paid Users)',
      'commission_rate': 0.0,
      'payout_per_user_inr': 30,
      'min_active_referrals': 50,
      'min_monthly_volume_inr': 0,
      'min_payout_threshold_inr': 1000,
      'tds_rate': 0.05,
      'settlement_cycle': 'Priority UPI / IMPS / NEFT (Min ₹1,000)',
      'perks': [
        '₹30 INR payout per verified paid Basic or Pro user starting from your 51st paid referral onward',
        'Complimentary AlphaJournal Pro unlocked automatically once 50 distinct referred users pay for Basic or Pro',
        'Referred monthly subscribers continue receiving Month 1 at ₹239 (Basic) or ₹399 (Pro)',
        'Quarterly Form 16A TDS statement and priority partner support',
      ],
      'sort_order': 2,
    },
  ];

  static List<Map<String, Object?>> _defaultTerms() => [
    {
      'id': 'term-1',
      'clause_code': 'PAYOUT-SCHEDULE-01',
      'version': '2026.2-INR',
      'title': 'Tiered Per-User INR Commission (₹10 First 50 · ₹30 After 50)',
      'category': 'payouts_tax',
      'summary':
          'Earn ₹10 per verified paid Basic/Pro user for your first 50 conversions and ₹30 per paid user from conversion #51 onward.',
      'body':
          'Under Revision 2026.2-INR, approved AlphaJournal affiliates earn ₹10 INR per verified distinct paying subscriber for their first 50 paid Basic or Pro conversions (users #1–50). Starting from the 51st verified paid Basic or Pro subscriber onward (users #51+), affiliate commission increases to ₹30 INR per verified paid conversion. Payouts are settled exclusively in INR (₹) via NPCI UPI (VPA), Bank NEFT, IMPS, or RTGS with a ₹1,000 minimum withdrawal threshold.',
      'mandatory': true,
      'sort_order': 1,
    },
    {
      'id': 'term-2',
      'clause_code': 'SUBSCRIBER-OFFER-02',
      'version': '2026.2-INR',
      'title':
          'Monthly Month-1 Subscriber Discount, Validity & One-User-at-a-Time Limit',
      'category': 'attribution',
      'summary':
          'Referred users get Month 1 at ₹239 (Basic) or ₹399 (Pro) on monthly plans, renewing at ₹299/₹499 from Month 2; strictly 1 code per user lifetime.',
      'body':
          'A valid, active affiliate referral code discounts only the first month of a new subscriber\'s Monthly subscription: Basic Monthly is ₹239 for Month 1 (₹60 off ₹299) and renews at ₹299/mo from Month 2; Pro Monthly is ₹399 for Month 1 (₹100 off ₹499) and renews at ₹499/mo from Month 2. Annual plans (Basic ₹2,868/yr, Pro ₹4,788/yr) already include the 20% discounted rate and credit the referring affiliate without stacking extra discount. Each user account may redeem at most one referral code in its lifetime on their first paid checkout only; codes require an active partner within the offer validity window.',
      'mandatory': true,
      'sort_order': 2,
    },
    {
      'id': 'term-3',
      'clause_code': 'AFFILIATE-COUPON-BAN-03',
      'version': '2026.2-INR',
      'title': 'Strict Prohibition on Affiliate Coupon Use & Self-Referrals',
      'category': 'conduct',
      'summary':
          'Affiliates are strictly prohibited from redeeming their own or any other affiliate\'s referral or coupon codes.',
      'body':
          'Approved, active, pending, or suspended affiliate accounts are prohibited from applying their own referral code, another affiliate\'s referral code, or any promotional referral coupon to their own subscription checkout. Self-referrals, circular referrals between partner accounts, paid brand-keyword bidding on "AlphaJournal", and coupon spoofing are enforced technically and contractually and will result in commission forfeiture and permanent suspension.',
      'mandatory': true,
      'sort_order': 3,
    },
    {
      'id': 'term-4',
      'clause_code': 'FREE-PRO-MILESTONE-04',
      'version': '2026.2-INR',
      'title': '50 Paid Basic/Pro Referrals Required for Complimentary Pro',
      'category': 'attribution',
      'summary':
          'No complimentary Basic or Pro tier is provided upon approval; free Pro unlocks automatically only at 50 verified paid Basic/Pro referrals.',
      'body':
          'Approval into the AlphaJournal Affiliate Program does not include complimentary Basic or Pro access. Affiliates start on the Free tier (or may purchase Basic or Pro at standard pricing without using any referral/coupon code). Complimentary AlphaJournal Pro unlocks automatically once 50 distinct referred users complete verified Basic or Pro payments. If refunds, chargebacks, or fraud reversals reduce verified paid conversions below 50, or if the affiliate account is suspended, complimentary Pro access is automatically revoked.',
      'mandatory': true,
      'sort_order': 4,
    },
    {
      'id': 'term-5',
      'clause_code': 'TDS-CLAWBACK-05',
      'version': '2026.2-INR',
      'title': 'Section 194H TDS, GST Compliance & Refund Clawbacks',
      'category': 'payouts_tax',
      'summary':
          '5% statutory TDS u/s 194H applies where required; refunded or disputed subscriptions reverse commissions and milestone counts.',
      'body':
          'In accordance with Section 194H of the Indian Income Tax Act, 1961, AlphaJournal deducts 5% statutory TDS where applicable and issues quarterly Form 16A records against verified PAN details. GST-registered partners may provide a valid 15-character GSTIN. Subscription plan upgrades, downgrades, or renewals by an already-converted user do not generate duplicate commissions. Refunds, payment disputes, or chargebacks automatically reverse the associated commission and decrement the verified paid referral count.',
      'mandatory': true,
      'sort_order': 5,
    },
    {
      'id': 'term-6',
      'clause_code': 'SEBI-ASCI-COMPLIANCE-06',
      'version': '2026.2-INR',
      'title': 'SEBI & ASCI Finfluencer Disclosure Mandate',
      'category': 'compliance_sebi',
      'summary':
          'Mandatory commercial referral disclosure and prohibition on guaranteed return claims or unregistered investment advice.',
      'body':
          'Partners must clearly disclose that their link or code is a commercial referral in accordance with ASCI Guidelines for Influencer Advertising in Digital Media and applicable SEBI circulars. Partners must never promise guaranteed trading profits, assured returns, or represent AlphaJournal software tools as SEBI-registered portfolio management or advisory tips.',
      'mandatory': true,
      'sort_order': 6,
    },
  ];

  static Map<String, Object?> _demo() => {
    'profile': {
      'id': 'demo-affiliate',
      'affiliate_code': 'PARTNER26',
      'custom_slug': 'nitish-trades',
      'tier': 'starter',
      'commission_rate': 0.0,
      'current_commission_inr': 10.0,
      'paid_referrals_count': 11,
      'free_pro_threshold': 50,
      'complimentary_pro_unlocked': false,
      'tds_rate': 0.05,
      'gst_registered': true,
      'gstin': '27ABCDE1234F1Z5',
      'pan_number': 'ABCDE1234F',
      'terms_version_accepted': '2026.2-INR',
      'terms_accepted_at': '2026-11-21T09:00:00Z',
      'currency': 'INR',
      'total_referrals': 18,
      'active_referrals': 11,
      'total_earnings': 184000.0,
      'unpaid_balance': 64000.0,
      'paid_earnings': 120000.0,
      'payout_method': 'upi',
      'payout_details': {
        'payout_account': 'nitish.alpha@okhdfcbank',
        'upi_id': 'nitish.alpha@okhdfcbank',
        'account_holder': 'Nitish Kumar',
        'bank_name': 'HDFC Bank',
        'account_number': '50100482910421',
        'ifsc': 'HDFC0000240',
        'account_type': 'Savings',
        'pan': 'ABCDE1234F',
        'gstin': '27ABCDE1234F1Z5',
      },
      'minimum_payout_threshold': 1000.0,
      'auto_payout_enabled': true,
      'status': 'active',
    },
    'campaigns': [
      {
        'id': 'cmp-1',
        'name': 'NIFTY Weekly Journal Walkthrough',
        'slug': 'weekly-journal',
        'channel': 'youtube',
        'status': 'active',
        'clicks': 418,
        'conversions_count': 7,
        'revenue_generated_inr': 84000.0,
        'created_at': '2026-02-03T10:00:00Z',
      },
      {
        'id': 'cmp-2',
        'name': 'Sunday FinNifty Prep Notes',
        'slug': 'sunday-notes',
        'channel': 'newsletter',
        'status': 'active',
        'clicks': 265,
        'conversions_count': 4,
        'revenue_generated_inr': 56000.0,
        'created_at': '2026-02-17T10:00:00Z',
      },
      {
        'id': 'cmp-3',
        'name': 'Price Action Checklist Guide',
        'slug': 'checklist-guide',
        'channel': 'website',
        'status': 'active',
        'clicks': 129,
        'conversions_count': 3,
        'revenue_generated_inr': 44000.0,
        'created_at': '2026-03-01T10:00:00Z',
      },
    ],
    'referrals': [
      for (int i = 0; i < 12; i++)
        {
          'id': 'ref-${100 + i}',
          'referral_code': 'nitish-trades',
          'channel': const ['youtube', 'newsletter', 'website'][i % 3],
          'plan_tier': i % 4 == 0 ? 'enterprise' : 'pro',
          'subscription_amount_inr': i % 4 == 0 ? 999.0 : 2499.0,
          'commission_rate': 0.25,
          'status': i < 10
              ? 'converted'
              : i < 11
              ? 'pending'
              : 'churned',
          'bonus_awarded': i < 10 ? (i % 4 == 0 ? 2000.0 : 1200.0) : 0.0,
          'tds_deducted_inr': i < 10 ? (i % 4 == 0 ? 100.0 : 60.0) : 0.0,
          'net_commission_inr': i < 10 ? (i % 4 == 0 ? 1900.0 : 1140.0) : 0.0,
          'created_at': DateTime.utc(2026, 4, 15 - i).toIso8601String(),
        },
    ],
    'payouts': [
      {
        'id': 'pay-101',
        'amount': 60000.0,
        'gross_amount_inr': 60000.0,
        'tds_amount_inr': 3000.0,
        'gst_amount_inr': 0.0,
        'net_amount_inr': 57000.0,
        'currency': 'INR',
        'status': 'paid',
        'payout_method': 'upi',
        'payout_destination': {
          'payout_account': 'nitish.alpha@okhdfcbank',
          'upi_id': 'nitish.alpha@okhdfcbank',
          'pan': 'ABCDE1234F',
        },
        'transaction_reference': 'UTR609018492011',
        'processed_at': '2026-03-31T16:00:00Z',
        'created_at': '2026-03-29T11:00:00Z',
      },
      {
        'id': 'pay-100',
        'amount': 60000.0,
        'gross_amount_inr': 60000.0,
        'tds_amount_inr': 3000.0,
        'gst_amount_inr': 0.0,
        'net_amount_inr': 57000.0,
        'currency': 'INR',
        'status': 'paid',
        'payout_method': 'bank_neft',
        'payout_destination': {
          'payout_account': '50100482910421 · HDFC Bank (HDFC0000240)',
          'account_number': '50100482910421',
          'ifsc': 'HDFC0000240',
          'bank_name': 'HDFC Bank',
          'pan': 'ABCDE1234F',
        },
        'transaction_reference': 'HDFCN26059482190',
        'processed_at': '2026-02-28T16:00:00Z',
        'created_at': '2026-02-26T11:00:00Z',
      },
    ],
    'assets': [
      {
        'id': 'ast-1',
        'title':
            'Introduce Your Indian Trading Workspace (SEBI/ASCI Compliant)',
        'format': 'Social caption',
        'body':
            'Plan NSE/BSE setups, log execution discipline, and review R-multiples in ₹ INR with AlphaJournal. Explore my workspace: {link}\n\nDisclosure: Referral partner link — I may earn a commission on qualifying subscriptions. Educational software only; not SEBI-registered investment advice.',
        'published': true,
      },
      {
        'id': 'ast-2',
        'title': 'Weekend NIFTY & BankNIFTY Review Newsletter',
        'format': 'Newsletter',
        'body':
            'Bring your F&O journal, strategy playbooks, and pre-market notes into one unified Indian desk. Start here: {link}\n\nAffiliate disclosure: I may receive a referral commission from AlphaJournal. Securities market investments are subject to market risks.',
        'published': true,
      },
      {
        'id': 'ast-3',
        'title': 'YouTube Description & Pin Comment Starter',
        'format': 'Video',
        'body':
            'Tools used in today’s market breakdown: {link}\n\nPartner disclosure: This is an AlphaJournal partner link. I may earn a commission at no extra cost to you. Trading in equities and derivatives involves substantial risk.',
        'published': true,
      },
    ],
    'tiers': _defaultTiers(),
    'terms': _defaultTerms(),
  };
}
