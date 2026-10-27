import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import 'package:tradex/core/config/supabase_config.dart';

/// Represents a persistent link between a market ticker symbol and an entity
/// across alphajournal (trader note, trade journal entry, strategy playbook,
/// community post, or direct message).
///
/// Because market tickers undergo daily quotes, price updates, splits, and
/// symbol updates, storing references directly in this dedicated table prevents
/// irregularities and desynchronization across the app.
class EntityTickerLink {
  const EntityTickerLink({
    required this.id,
    required this.userId,
    required this.entityType,
    required this.entityId,
    required this.ticker,
    this.contextSource = 'inline',
    this.priceAtLink,
    this.metadata = const <String, dynamic>{},
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String userId;

  /// One of: 'note', 'journal', 'strategy', 'community_post', 'message'.
  final String entityType;
  final String entityId;
  final String ticker;

  /// Source context: 'inline', 'manual', 'tag', 'setup', 'shared_ref'.
  final String contextSource;

  /// Optional price of the ticker at the moment it was linked.
  final double? priceAtLink;
  final Map<String, dynamic> metadata;
  final DateTime createdAt;
  final DateTime updatedAt;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'user_id': userId,
    'entity_type': entityType,
    'entity_id': entityId,
    'ticker': ticker,
    'context_source': contextSource,
    if (priceAtLink != null) 'price_at_link': priceAtLink,
    'metadata': metadata,
    'created_at': createdAt.toIso8601String(),
    'updated_at': updatedAt.toIso8601String(),
  };

  factory EntityTickerLink.fromJson(
    Map<String, dynamic> json,
  ) => EntityTickerLink(
    id: json['id']?.toString() ?? '',
    userId: json['user_id']?.toString() ?? '',
    entityType: json['entity_type']?.toString() ?? 'note',
    entityId: json['entity_id']?.toString() ?? '',
    ticker: (json['ticker']?.toString() ?? '').toUpperCase(),
    contextSource: json['context_source']?.toString() ?? 'inline',
    priceAtLink: (json['price_at_link'] as num?)?.toDouble(),
    metadata:
        (json['metadata'] as Map<String, dynamic>?) ??
        const <String, dynamic>{},
    createdAt: json['created_at'] == null
        ? DateTime.now()
        : DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now(),
    updatedAt: json['updated_at'] == null
        ? DateTime.now()
        : DateTime.tryParse(json['updated_at'].toString()) ?? DateTime.now(),
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is EntityTickerLink &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}

/// Repository and service for recording, querying, and observing ticker links
/// across all alphajournal surfaces (Notes, Journal, Strategies, Community, Messages).
///
/// Ensures every linked ticker is stored directly to the `entity_ticker_links`
/// table so that daily ticker data updates and symbol modifications do not cause
/// irregularities or lose historical associations.
class EntityTickerLinksRepository {
  EntityTickerLinksRepository._();

  static final EntityTickerLinksRepository instance =
      EntityTickerLinksRepository._();

  static final RegExp _cashtagRegex = RegExp(
    r'(?<![\$\w])\$([A-Za-z\^][A-Za-z0-9\.\-\_\^\=]{0,9})\b(?!\$)',
  );

  static final RegExp _uuidRegex = RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
  );

  /// Helper to extract all `$TICKER` cashtags from markdown or plain text.
  static Set<String> extractTickers(String? text) {
    if (text == null || text.trim().isEmpty) return const <String>{};
    final Set<String> result = <String>{};
    for (final Match match in _cashtagRegex.allMatches(text)) {
      final String? sym = match.group(1)?.toUpperCase().trim();
      if (sym != null && sym.isNotEmpty) {
        result.add(sym);
      }
    }
    return result;
  }

  final List<EntityTickerLink> _links = <EntityTickerLink>[];
  final StreamController<List<EntityTickerLink>> _streamController =
      StreamController<List<EntityTickerLink>>.broadcast();

  /// Records ticker links for an entity directly into the repository and
  /// synchronizes to the backend `entity_ticker_links` table if connected.
  Future<List<EntityTickerLink>> recordLinks({
    required String entityType,
    required String entityId,
    required Iterable<String> tickers,
    String? userId,
    String contextSource = 'inline',
    double? priceAtLink,
    Map<String, dynamic> metadata = const <String, dynamic>{},
  }) async {
    final String uid =
        userId ?? SupabaseConfig.client?.auth.currentUser?.id ?? '';
    final DateTime now = DateTime.now();

    final Set<String> cleanedTickers = tickers
        .map((t) => t.replaceAll(r'$', '').trim().toUpperCase())
        .where((t) => t.isNotEmpty)
        .toSet();

    if (cleanedTickers.isEmpty) {
      await removeLinks(entityType: entityType, entityId: entityId);
      return const <EntityTickerLink>[];
    }

    final List<EntityTickerLink> updatedLinks = <EntityTickerLink>[];

    // Remove existing links for this entity that are no longer in the set
    _links.removeWhere(
      (l) =>
          l.entityType == entityType &&
          l.entityId == entityId &&
          !cleanedTickers.contains(l.ticker),
    );

    for (final String symbol in cleanedTickers) {
      final int existingIdx = _links.indexWhere(
        (l) =>
            l.entityType == entityType &&
            l.entityId == entityId &&
            l.ticker == symbol,
      );

      if (existingIdx >= 0) {
        final EntityTickerLink current = _links[existingIdx];
        final EntityTickerLink updated = EntityTickerLink(
          id: current.id,
          userId: uid,
          entityType: entityType,
          entityId: entityId,
          ticker: symbol,
          contextSource: contextSource,
          priceAtLink: priceAtLink ?? current.priceAtLink,
          metadata: <String, dynamic>{...current.metadata, ...metadata},
          createdAt: current.createdAt,
          updatedAt: now,
        );
        _links[existingIdx] = updated;
        updatedLinks.add(updated);
      } else {
        final EntityTickerLink created = EntityTickerLink(
          id: const Uuid().v4(),
          userId: uid,
          entityType: entityType,
          entityId: entityId,
          ticker: symbol,
          contextSource: contextSource,
          priceAtLink: priceAtLink,
          metadata: metadata,
          createdAt: now,
          updatedAt: now,
        );
        _links.add(created);
        updatedLinks.add(created);
      }
    }

    _notify();

    // Async push to backend Supabase table if online
    final client = SupabaseConfig.client;
    if (client != null && _uuidRegex.hasMatch(uid)) {
      try {
        final List<Map<String, dynamic>> payload = updatedLinks
            .map((l) {
              final map = l.toJson();
              if (!_uuidRegex.hasMatch(l.id)) {
                // Remove local client-generated id so PostgreSQL generates a valid UUID default
                map.remove('id');
              }
              return map;
            })
            .toList(growable: false);
        await client
            .from('entity_ticker_links')
            .upsert(
              payload,
              onConflict: 'user_id,entity_type,entity_id,ticker',
            );
      } catch (e) {
        debugPrint('[EntityTickerLinksRepository] Backend sync warning: $e');
      }
    }

    return updatedLinks;
  }

  /// Removes ticker links for an entity, optionally filtered by a specific ticker.
  Future<void> removeLinks({
    required String entityType,
    required String entityId,
    String? ticker,
  }) async {
    final String? sym = ticker?.replaceAll(r'$', '').trim().toUpperCase();
    _links.removeWhere(
      (l) =>
          l.entityType == entityType &&
          l.entityId == entityId &&
          (sym == null || l.ticker == sym),
    );
    _notify();

    final client = SupabaseConfig.client;
    if (client != null) {
      try {
        var query = client
            .from('entity_ticker_links')
            .delete()
            .eq('entity_type', entityType)
            .eq('entity_id', entityId);
        if (sym != null) {
          query = query.eq('ticker', sym);
        }
        await query;
      } catch (e) {
        debugPrint('[EntityTickerLinksRepository] Backend delete warning: $e');
      }
    }
  }

  /// Returns all ticker links associated with a given ticker symbol.
  List<EntityTickerLink> getLinksForTicker(String ticker) {
    final String sym = ticker.replaceAll(r'$', '').trim().toUpperCase();
    return _links.where((l) => l.ticker == sym).toList(growable: false);
  }

  /// Returns all ticker links associated with a specific entity.
  List<EntityTickerLink> getLinksForEntity(String entityType, String entityId) {
    return _links
        .where((l) => l.entityType == entityType && l.entityId == entityId)
        .toList(growable: false);
  }

  /// Observes real-time changes to links for a specific ticker symbol.
  Stream<List<EntityTickerLink>> watchLinksForTicker(String ticker) {
    final String sym = ticker.replaceAll(r'$', '').trim().toUpperCase();
    return watchAll().map(
      (links) => links.where((l) => l.ticker == sym).toList(growable: false),
    );
  }

  /// Observes all ticker links.
  Stream<List<EntityTickerLink>> watchAll() {
    return Stream<List<EntityTickerLink>>.multi((controller) {
      controller.add(List<EntityTickerLink>.unmodifiable(_links));
      final sub = _streamController.stream.listen(
        controller.add,
        onError: controller.addError,
      );
      controller.onCancel = sub.cancel;
    });
  }

  void _notify() {
    if (!_streamController.isClosed) {
      _streamController.add(List<EntityTickerLink>.unmodifiable(_links));
    }
  }

  @visibleForTesting
  void clearForTesting() {
    _links.clear();
    _notify();
  }
}
