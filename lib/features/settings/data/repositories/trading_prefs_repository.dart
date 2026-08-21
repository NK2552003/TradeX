import 'package:flutter/material.dart';
import 'package:tradex/core/app-ui/app_ui.dart';
import 'package:tradex/features/settings/models/trading_prefs_model.dart';

abstract class TradingPrefsRepository {
  Future<TradingPrefsModel> getPreferences();
  Future<TradingPrefsModel> updatePreferences(TradingPrefsModel prefs);
  Future<List<AppChecklistItem>> getChecklist();
  Future<List<AppChecklistItem>> updateChecklist(List<AppChecklistItem> items);
  Future<List<AppChecklistItem>> addChecklistItem(
    String label, {
    String? description,
  });
  Future<List<AppChecklistItem>> deleteChecklistItem(String id);
}

class TradingPrefsRepositoryImpl implements TradingPrefsRepository {
  TradingPrefsModel _prefs = TradingPrefsModel.defaultPrefs();

  List<AppChecklistItem> _checklist = <AppChecklistItem>[
    const AppChecklistItem(
      id: 'chk_1',
      label: 'Trend alignment verified on higher timeframe (Daily/4H)',
      description: 'Ensure 200 EMA slope agrees with trade direction',
      done: true,
      icon: Icons.trending_up,
    ),
    const AppChecklistItem(
      id: 'chk_2',
      label: 'Key support/resistance level identified and tested',
      description: 'Check for volume confluence and liquidity sweep',
      done: true,
      icon: Icons.horizontal_rule,
    ),
    const AppChecklistItem(
      id: 'chk_3',
      label: 'Calculated stop-loss and 1:2+ risk-to-reward ratio',
      description: 'Max risk capped at 2% account equity',
      done: false,
      icon: Icons.shield_outlined,
    ),
    const AppChecklistItem(
      id: 'chk_4',
      label: 'High-impact economic news checked (FOMC, CPI, NFP)',
      description:
          'Avoid entering positions within 30 min of red-folder events',
      done: false,
      icon: Icons.event_note_outlined,
    ),
  ];

  @override
  Future<TradingPrefsModel> getPreferences() async {
    await Future<void>.delayed(const Duration(milliseconds: 200));
    return _prefs;
  }

  @override
  Future<TradingPrefsModel> updatePreferences(TradingPrefsModel prefs) async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    _prefs = prefs;
    return _prefs;
  }

  @override
  Future<List<AppChecklistItem>> getChecklist() async {
    await Future<void>.delayed(const Duration(milliseconds: 250));
    return List<AppChecklistItem>.from(_checklist);
  }

  @override
  Future<List<AppChecklistItem>> updateChecklist(
    List<AppChecklistItem> items,
  ) async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    _checklist = List<AppChecklistItem>.from(items);
    return _checklist;
  }

  @override
  Future<List<AppChecklistItem>> addChecklistItem(
    String label, {
    String? description,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    final newItem = AppChecklistItem(
      id: 'chk_${DateTime.now().millisecondsSinceEpoch}',
      label: label,
      description: description,
      done: false,
      icon: Icons.check_box_outline_blank,
    );
    _checklist.add(newItem);
    return List<AppChecklistItem>.from(_checklist);
  }

  @override
  Future<List<AppChecklistItem>> deleteChecklistItem(String id) async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    _checklist.removeWhere((item) => item.id == id);
    return List<AppChecklistItem>.from(_checklist);
  }
}
