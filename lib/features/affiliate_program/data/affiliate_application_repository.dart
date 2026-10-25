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

  @override
  Future<AffiliateApplicationModel?> getForUser(String userId) async {
    if (SupabaseConfig.isConfigured) {
      try {
        final client = SupabaseConfig.client!;
        final res = await client
            .from('affiliate_applications')
            .select()
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
    if (SupabaseConfig.isConfigured) {
      try {
        final client = SupabaseConfig.client!;
        final res = await client
            .from('affiliate_applications')
            .select()
            .order('created_at', ascending: false);

        return (res as List)
            .map((item) => AffiliateApplicationModel.fromJson(item))
            .toList();
      } catch (e) {
        debugPrint(
          '[AffiliateApplicationRepository] listApplications error: $e',
        );
        rethrow;
      }
    }

    final List<AffiliateApplicationModel> result = _applications.values.toList()
      ..sort((AffiliateApplicationModel a, AffiliateApplicationModel b) {
        final DateTime left = a.submittedAt ?? DateTime(1970);
        final DateTime right = b.submittedAt ?? DateTime(1970);
        return right.compareTo(left);
      });
    return result;
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
            .select()
            .single();
      } else {
        res = await client
            .from('affiliate_applications')
            .update(payload)
            .eq('id', existing['id'])
            .select()
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
    if (SupabaseConfig.isConfigured) {
      final client = SupabaseConfig.client!;
      await client.rpc(
        'review_affiliate_application',
        params: {
          'p_application_id': applicationId,
          'p_approve': approve,
          'p_review_notes': notes,
        },
      );
      final res = await client
          .from('affiliate_applications')
          .select()
          .eq('id', applicationId)
          .single();
      return AffiliateApplicationModel.fromJson(res);
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
