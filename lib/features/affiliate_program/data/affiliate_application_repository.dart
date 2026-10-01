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
            .maybeSingle();

        if (res != null) {
          return AffiliateApplicationModel.fromJson(res);
        }
      } catch (e) {
        debugPrint('[AffiliateApplicationRepository] getForUser error: $e');
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
        debugPrint('[AffiliateApplicationRepository] listApplications error: $e');
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
      try {
        final client = SupabaseConfig.client!;
        final payload = pending.toJson();

        final res = await client
            .from('affiliate_applications')
            .upsert(payload)
            .select()
            .single();

        return AffiliateApplicationModel.fromJson(res);
      } catch (e) {
        debugPrint('[AffiliateApplicationRepository] submit error: $e');
      }
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
    if (SupabaseConfig.isConfigured && approve) {
      try {
        final client = SupabaseConfig.client!;
        await client.rpc(
          'approve_affiliate_application',
          params: {
            'p_application_id': applicationId,
            'p_review_notes': notes,
          },
        );

        final res = await client
            .from('affiliate_applications')
            .select()
            .eq('id', applicationId)
            .maybeSingle();

        if (res != null) {
          return AffiliateApplicationModel.fromJson(res);
        }
      } catch (e) {
        debugPrint('[AffiliateApplicationRepository] review RPC error: $e');
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
