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
                'commission_rate, payout_method, payout_details',
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
          final String tier = affProfRes?['tier']?.toString() ?? 'gold';
          final double commissionRate =
              (affProfRes?['commission_rate'] as num?)?.toDouble() ?? 0.25;

          final Map<String, Object?> liveProfile = <String, Object?>{
            'id': userId,
            'affiliate_code': userRefCode,
            'custom_slug': handle,
            'display_name': displayName,
            'tier': tier,
            'commission_rate': commissionRate,
            'tds_rate': 0.05,
            'currency': 'INR',
            'total_referrals': (referralsRes as List?)?.length ?? 0,
            'active_referrals':
                (referralsRes as List?)
                    ?.where(
                      (dynamic r) => r is Map && r['status'] == 'converted',
                    )
                    .length ??
                0,
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
            'status': 'active',
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
      'headline': 'Exclusive 20% Discount Link',
      'body':
          'Get instant access to AlphaJournal Pro analytics and AI Copilot.',
      'call_to_action': 'Claim Partner Access',
      'landing_path': '/r/$slug',
      'tags': ['Link', 'CustomSlug', 'FastOnboarding'],
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
      'tier_code': 'standard',
      'display_name': 'Tier 1 · Standard Partner',
      'commission_rate': 0.15,
      'min_active_referrals': 0,
      'min_monthly_volume_inr': 0,
      'min_payout_threshold_inr': 1000,
      'tds_rate': 0.05,
      'settlement_cycle': 'Weekly NEFT / UPI (Min ₹1,000)',
      'perks': [
        '15% recurring INR revenue share on Pro & Enterprise plans',
        'Custom referral slug & UTM campaign link builder',
        'Direct NPCI UPI & Bank NEFT/IMPS settlements in INR (₹)',
        ' Creator media kit with SEBI/ASCI compliant disclosures',
      ],
      'sort_order': 1,
    },
    {
      'tier_code': 'silver',
      'display_name': 'Tier 2 · Silver Growth Partner',
      'commission_rate': 0.20,
      'min_active_referrals': 10,
      'min_monthly_volume_inr': 25000,
      'min_payout_threshold_inr': 1000,
      'tds_rate': 0.05,
      'settlement_cycle': 'Bi-weekly IMPS / UPI (Min ₹1,000)',
      'perks': [
        '20% recurring INR revenue share on all referred traders',
        'Complimentary AlphaJournal Pro workspace (₹2,499/mo value)',
        'Verified Partner badge on Community posts & strategies',
        'Co-branded referral landing page with creator avatar',
      ],
      'sort_order': 2,
    },
    {
      'tier_code': 'gold',
      'display_name': 'Tier 3 · Gold Pro Partner',
      'commission_rate': 0.25,
      'min_active_referrals': 25,
      'min_monthly_volume_inr': 75000,
      'min_payout_threshold_inr': 1000,
      'tds_rate': 0.05,
      'settlement_cycle': 'T+2 Priority IMPS / UPI (Min ₹1,000)',
      'perks': [
        '25% recurring INR revenue share on Pro & Enterprise plans',
        'Exclusive 20% audience discount code on first renewal',
        'Dedicated partner manager & custom Hindi/English creatives',
        'Automated quarterly Form 16A TDS & GST invoice ledger',
      ],
      'sort_order': 3,
    },
    {
      'tier_code': 'platinum',
      'display_name': 'Tier 4 · Institutional Desk Partner',
      'commission_rate': 0.35,
      'min_active_referrals': 50,
      'min_monthly_volume_inr': 200000,
      'min_payout_threshold_inr': 1000,
      'tds_rate': 0.05,
      'settlement_cycle': 'Instant UPI / RTGS Desk Settlement',
      'perks': [
        '35% lifetime INR revenue share across retail & desk seats',
        'Complimentary Business Desk seat (₹999/mo value)',
        'Co-hosted live trading bootcamps & INR sponsorship grants',
        'Custom webhook attribution & sub-affiliate rev-share splits',
      ],
      'sort_order': 4,
    },
  ];

  static List<Map<String, Object?>> _defaultTerms() => [
    {
      'id': 'term-1',
      'clause_code': 'INR-SETTLEMENT-01',
      'version': '2026.1-INR',
      'title': '100% INR (₹) Settlement & Minimum Threshold',
      'category': 'payouts_tax',
      'summary':
          'All commissions, bonuses, and settlements are denominated and paid exclusively in Indian Rupees (₹ INR).',
      'body':
          'Commissions are calculated as a percentage of net qualifying subscription revenue collected in INR (excluding 18% GST). Minimum withdrawal threshold is ₹1,000 INR (configurable upward by the partner). Supported payout rails are NPCI UPI (VPA), Bank NEFT, IMPS, and RTGS to verified Indian bank accounts with a valid 11-character IFSC.',
      'mandatory': true,
      'sort_order': 1,
    },
    {
      'id': 'term-2',
      'clause_code': 'TDS-GST-02',
      'version': '2026.1-INR',
      'title': 'Indian Tax Deduction at Source (TDS u/s 194H) & GST Compliance',
      'category': 'payouts_tax',
      'summary':
          '5% statutory TDS applies under Section 194H of the Income Tax Act; GST-registered partners may submit GSTIN.',
      'body':
          'In accordance with Section 194H of the Indian Income Tax Act, 1961, AlphaJournal deducts 5% TDS on gross affiliate commission payouts where applicable and issues quarterly Form 16A certificates against your verified 10-character PAN. Partners with a valid 15-character GSTIN may enable GST invoicing in Affiliate Settings.',
      'mandatory': true,
      'sort_order': 2,
    },
    {
      'id': 'term-3',
      'clause_code': 'ATTRIBUTION-COOKIE-03',
      'version': '2026.1-INR',
      'title':
          '30-Day First-Party Referral Attribution & Qualifying Conversions',
      'category': 'attribution',
      'summary':
          '30-day attribution window on /r/:slug links with UTM campaign tracking and billing webhook qualification.',
      'body':
          'When a prospective trader visits your referral link (/r/:code?utm_campaign=:slug), attribution is persisted for 30 days. Signups create a pending referral record; commissions are credited to your unpaid INR balance once the referred subscriber completes a verified paid subscription (Pro ₹2,499/mo or Business ₹999/mo) and clears the 7-day refund guard.',
      'mandatory': true,
      'sort_order': 3,
    },
    {
      'id': 'term-4',
      'clause_code': 'SEBI-ASCI-COMPLIANCE-04',
      'version': '2026.1-INR',
      'title': 'SEBI & ASCI Finfluencer Disclosure Mandate',
      'category': 'compliance_sebi',
      'summary':
          'Mandatory affiliate disclosure and prohibition on guaranteed return claims or unregistered investment advice.',
      'body':
          'Partners must clearly disclose that their link is a commercial referral link in accordance with ASCI Guidelines for Influencer Advertising in Digital Media and SEBI circulars. Partners must never promise guaranteed trading profits, assured returns, or represent AlphaJournal software tools as SEBI-registered portfolio management or advisory tips.',
      'mandatory': true,
      'sort_order': 4,
    },
    {
      'id': 'term-5',
      'clause_code': 'ANTI-ABUSE-05',
      'version': '2026.1-INR',
      'title': 'Prohibition of Self-Referrals, Brand Bidding & Coupon Spoofing',
      'category': 'conduct',
      'summary':
          'Self-referrals, paid search bidding on AlphaJournal brand keywords, and misleading coupon pages are strictly prohibited.',
      'body':
          'Accounts found referring their own trading seats, running Google/Meta paid ads targeting "AlphaJournal" brand terms without written authorization, or injecting unauthorized tracking scripts will have pending commissions forfeited and partner access suspended by the Institutional Desk Administrator.',
      'mandatory': true,
      'sort_order': 5,
    },
  ];

  static Map<String, Object?> _demo() => {
    'profile': {
      'id': 'demo-affiliate',
      'affiliate_code': 'PARTNER26',
      'custom_slug': 'nitish-trades',
      'tier': 'gold',
      'commission_rate': 0.25,
      'tds_rate': 0.05,
      'gst_registered': true,
      'gstin': '27ABCDE1234F1Z5',
      'pan_number': 'ABCDE1234F',
      'terms_version_accepted': '2026.1-INR',
      'terms_accepted_at': '2026-01-15T09:00:00Z',
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
