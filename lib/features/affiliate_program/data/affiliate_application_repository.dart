import 'package:flutter/foundation.dart';
import 'package:tradex/core/config/supabase_config.dart';
import 'package:tradex/features/affiliate_program/models/affiliate_application_model.dart';

abstract class AffiliateApplicationRepository {
  Future<AffiliateApplicationModel?> getForUser(String userId);

  Future<List<AffiliateApplicationModel>> listApplications();

  Future<AffiliateApplicationModel> submit(
    AffiliateApplicationModel application,
  );

  Future<AffiliateApplicationModel> review({
    required String applicationId,
    required bool approve,
    String? notes,
  });
}

class AffiliateApplicationRepositoryImpl
    implements AffiliateApplicationRepository {
  AffiliateApplicationRepositoryImpl._();

  static final AffiliateApplicationRepositoryImpl instance =
      AffiliateApplicationRepositoryImpl._();

  final Map<String, AffiliateApplicationModel> _applications =
      <String, AffiliateApplicationModel>{};

  static const String _selectColumns =
      'id, user_id, full_name, email, phone, city, state, date_of_birth, '
      'gender, platforms, primary_platform, channel_handle, audience_reach, '
      'niches, sample_link, account_holder, bank_name, account_number, ifsc, '
      'account_type, pan, upi_id, status, review_notes, submitted_at, reviewed_at';

  @override
  Future<AffiliateApplicationModel?> getForUser(String userId) async {
    if (SupabaseConfig.isConfigured) {
      try {
        final client = SupabaseConfig.client!;
        final res = await client
            .from('affiliate_applications')
            .select(_selectColumns)
            .eq('user_id', userId)
            .order('created_at', ascending: false)
            .limit(1)
            .maybeSingle();

        if (res != null) {
          return AffiliateApplicationModel.fromJson(res);
        }
        return null;
      } catch (e) {
        debugPrint('[AffiliateApplicationRepository] getForUser error: $e');
        rethrow;
      }
    }

    for (final AffiliateApplicationModel application in _applications.values) {
      if (application.userId == userId) return application;
    }
    return null;
  }

  @override
  Future<List<AffiliateApplicationModel>> listApplications() async {
    if (SupabaseConfig.isConfigured && SupabaseConfig.client != null) {
      try {
        final client = SupabaseConfig.client!;
        final res = await client
            .from('affiliate_applications')
            .select(_selectColumns)
            .order('created_at', ascending: false)
            .limit(100);

        if (res.isNotEmpty) {
          final list = res
              .whereType<Map<String, dynamic>>()
              .map(AffiliateApplicationModel.fromJson)
              .toList();
          for (final a in list) {
            _applications[a.id] = a;
          }
          return list;
        }
      } catch (e) {
        debugPrint(
          '[AffiliateApplicationRepository] listApplications error: $e',
        );
      }
    }

    if (_applications.isEmpty) {
      _seedDefaultApplications();
    }

    final List<AffiliateApplicationModel> result = _applications.values.toList()
      ..sort((AffiliateApplicationModel a, AffiliateApplicationModel b) {
        final DateTime left = a.submittedAt ?? DateTime(1970);
        final DateTime right = b.submittedAt ?? DateTime(1970);
        return right.compareTo(left);
      });
    return result;
  }

  void _seedDefaultApplications() {
    final pendingApp = AffiliateApplicationModel(
      id: 'app_seed_nk2552003',
      userId: '002c19b4-2af7-4f29-9351-e283736677c4',
      fullName: 'Nitish Kumar',
      email: 'nk2552003@gmail.com',
      phone: '+91 98765 43210',
      city: 'Dehradun',
      state: 'Uttarakhand',
      dateOfBirth: DateTime(2003, 5, 25),
      gender: 'male',
      platforms: const <String>['youtube', 'telegram'],
      primaryPlatform: 'youtube',
      channelHandle: '@tradex_academy',
      audienceReach: '25,000+ traders',
      niches: const <String>['Price Action', 'Derivatives'],
      accountHolder: 'Nitish Kumar',
      bankName: 'HDFC Bank',
      accountNumber: '50100482910421',
      ifsc: 'HDFC0000240',
      accountType: 'savings',
      pan: 'ABCDE1234F',
      upiId: 'nk2552003@okhdfcbank',
      status: AffiliateApplicationStatus.pending,
      submittedAt: DateTime.now().subtract(const Duration(hours: 14)),
    );
    _applications[pendingApp.id] = pendingApp;
  }

  @override
  Future<AffiliateApplicationModel> submit(
    AffiliateApplicationModel application,
  ) async {
    final AffiliateApplicationModel pending = application.copyWith(
      status: AffiliateApplicationStatus.pending,
      submittedAt: DateTime.now(),
    );

    if (SupabaseConfig.isConfigured) {
      final client = SupabaseConfig.client!;
      if (client.auth.currentUser?.id != application.userId) {
        throw StateError('Sign in as the applicant to submit.');
      }
      final payload = pending.toJson()..remove('id');
      payload['review_notes'] = null;
      payload['reviewed_at'] = null;
      final existing = await client
          .from('affiliate_applications')
          .select('id,status')
          .eq('user_id', application.userId)
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();
      if (existing != null &&
          ['approved', 'suspended'].contains(existing['status'])) {
        throw StateError('This application has already been reviewed.');
      }
      final Map<String, dynamic> res;
      if (existing == null) {
        res = await client
            .from('affiliate_applications')
            .insert(payload)
            .select(_selectColumns)
            .single();
      } else {
        res = await client
            .from('affiliate_applications')
            .update(payload)
            .eq('id', existing['id'])
            .select(_selectColumns)
            .single();
      }
      return AffiliateApplicationModel.fromJson(res);
    }

    _applications[pending.id] = pending;
    return pending;
  }

  @override
  Future<AffiliateApplicationModel> review({
    required String applicationId,
    required bool approve,
    String? notes,
  }) async {
    if (SupabaseConfig.isConfigured && SupabaseConfig.client != null) {
      try {
        final client = SupabaseConfig.client!;
        if (approve) {
          try {
            await client.rpc(
              'approve_affiliate_application',
              params: {
                'p_application_id': applicationId,
                'p_review_notes': notes,
              },
            );
          } catch (_) {
            await client.rpc(
              'review_affiliate_application',
              params: {
                'p_application_id': applicationId,
                'p_approve': approve,
                'p_review_notes': notes,
              },
            );
          }
        } else {
          await client
              .from('affiliate_applications')
              .update({
                'status': 'rejected',
                'review_notes': notes,
                'reviewed_at': DateTime.now().toUtc().toIso8601String(),
              })
              .eq('id', applicationId);
        }
        final res = await client
            .from('affiliate_applications')
            .select(_selectColumns)
            .eq('id', applicationId)
            .maybeSingle();
        if (res != null) {
          final updated = AffiliateApplicationModel.fromJson(res);
          _applications[applicationId] = updated;
          return updated;
        }
      } catch (e) {
        debugPrint('[AffiliateApplicationRepository] review remote error: $e');
      }
    }

    final AffiliateApplicationModel? current = _applications[applicationId];
    if (current == null) {
      throw StateError('Affiliate application not found.');
    }
    final AffiliateApplicationModel reviewed = current.copyWith(
      status: approve
          ? AffiliateApplicationStatus.approved
          : AffiliateApplicationStatus.rejected,
      reviewNotes: notes?.trim(),
      reviewedAt: DateTime.now(),
    );
    _applications[applicationId] = reviewed;
    return reviewed;
  }
}
