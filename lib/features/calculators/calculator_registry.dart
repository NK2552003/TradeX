import 'package:flutter/material.dart';
import 'package:tradex/core/app-ui/app_ui.dart';

/// Every calculator the hub can open, in display order.
///
/// The hub filters this list; `CalculatorsScreen` maps [AppCalculatorMeta.id]
/// to a screen. Adding a tool means one entry here plus one screen file.
const List<AppCalculatorMeta> kAllCalculators = <AppCalculatorMeta>[
  // ── Trading ───────────────────────────────────────────────────────────────
  AppCalculatorMeta(
    id: 'position_size',
    name: 'Position Size',
    description: 'Quantity to buy for a fixed rupee risk per trade.',
    category: AppCalculatorCategory.trading,
    icon: Icons.straighten_outlined,
    tags: <String>['risk', 'sizing', 'stop loss', 'capital'],
  ),
  AppCalculatorMeta(
    id: 'risk_reward',
    name: 'Risk / Reward',
    description: 'R:R ratio and breakeven win rate for a setup.',
    category: AppCalculatorCategory.trading,
    icon: Icons.balance_outlined,
    tags: <String>['rr', 'target', 'stop loss', 'expectancy'],
  ),
  AppCalculatorMeta(
    id: 'brokerage',
    name: 'Brokerage & Charges',
    description: 'STT, GST, stamp duty and net P&L after all costs.',
    category: AppCalculatorCategory.trading,
    icon: Icons.receipt_outlined,
    tags: <String>['stt', 'gst', 'zerodha', 'upstox', 'charges', 'fees'],
  ),
  AppCalculatorMeta(
    id: 'margin',
    name: 'Margin',
    description: 'Span + exposure margin needed for a futures position.',
    category: AppCalculatorCategory.trading,
    icon: Icons.account_balance_outlined,
    tags: <String>['leverage', 'futures', 'span', 'exposure'],
  ),
  AppCalculatorMeta(
    id: 'pivot_points',
    name: 'Pivot Points',
    description: 'Standard, Camarilla and Woodie support / resistance.',
    category: AppCalculatorCategory.trading,
    icon: Icons.stacked_line_chart_outlined,
    tags: <String>['support', 'resistance', 'camarilla', 'woodie', 'levels'],
  ),
  AppCalculatorMeta(
    id: 'fibonacci',
    name: 'Fibonacci Levels',
    description: 'Retracement levels between a swing high and low.',
    category: AppCalculatorCategory.trading,
    icon: Icons.show_chart_outlined,
    tags: <String>['retracement', 'levels', 'swing', 'golden ratio'],
  ),
  AppCalculatorMeta(
    id: 'pnl',
    name: 'Profit & Loss',
    description: 'Absolute and percentage P&L for a closed trade.',
    category: AppCalculatorCategory.trading,
    icon: Icons.trending_up_outlined,
    tags: <String>['pnl', 'profit', 'loss', 'return', 'long', 'short'],
  ),

  // ── Options ───────────────────────────────────────────────────────────────
  AppCalculatorMeta(
    id: 'options_pnl',
    name: 'Options P&L',
    description: 'Payoff, breakeven and max loss for a single leg.',
    category: AppCalculatorCategory.options,
    icon: Icons.multiline_chart_outlined,
    tags: <String>['payoff', 'premium', 'call', 'put', 'breakeven'],
  ),
  AppCalculatorMeta(
    id: 'black_scholes',
    name: 'Black-Scholes',
    description: 'Theoretical premium plus all five Greeks.',
    category: AppCalculatorCategory.options,
    icon: Icons.calculate_outlined,
    tags: <String>['greeks', 'delta', 'gamma', 'theta', 'vega', 'iv'],
  ),
  AppCalculatorMeta(
    id: 'contract_value',
    name: 'Contract Value',
    description: 'Notional value of one lot at a given price.',
    category: AppCalculatorCategory.options,
    icon: Icons.inventory_2_outlined,
    tags: <String>['notional', 'lot size', 'exposure'],
  ),

  // ── Investing ─────────────────────────────────────────────────────────────
  AppCalculatorMeta(
    id: 'sip',
    name: 'SIP',
    description: 'Corpus built by a monthly systematic investment.',
    category: AppCalculatorCategory.investing,
    icon: Icons.autorenew_outlined,
    tags: <String>['mutual fund', 'monthly', 'compounding', 'corpus'],
  ),
  AppCalculatorMeta(
    id: 'lumpsum',
    name: 'Lumpsum',
    description: 'Future value of a one-time investment.',
    category: AppCalculatorCategory.investing,
    icon: Icons.savings_outlined,
    tags: <String>['one time', 'compounding', 'future value'],
  ),
  AppCalculatorMeta(
    id: 'fd',
    name: 'Fixed Deposit',
    description: 'Maturity amount with configurable compounding.',
    category: AppCalculatorCategory.investing,
    icon: Icons.account_balance_wallet_outlined,
    tags: <String>['fd', 'rd', 'interest', 'maturity', 'bank'],
  ),
  AppCalculatorMeta(
    id: 'cagr',
    name: 'CAGR',
    description: 'Annualised growth rate between two values.',
    category: AppCalculatorCategory.investing,
    icon: Icons.timeline_outlined,
    tags: <String>['cagr', 'annualised', 'growth', 'absolute return'],
  ),
  AppCalculatorMeta(
    id: 'inflation',
    name: 'Inflation Impact',
    description: 'What today’s money is worth years from now.',
    category: AppCalculatorCategory.investing,
    icon: Icons.trending_down_outlined,
    tags: <String>['purchasing power', 'real return', 'cpi'],
  ),
  AppCalculatorMeta(
    id: 'ppf',
    name: 'PPF',
    description: 'Public Provident Fund corpus over the lock-in.',
    category: AppCalculatorCategory.investing,
    icon: Icons.shield_outlined,
    tags: <String>['ppf', 'tax free', '15 years', 'retirement'],
  ),
  AppCalculatorMeta(
    id: 'emi',
    name: 'EMI',
    description: 'Monthly instalment and total interest on a loan.',
    category: AppCalculatorCategory.investing,
    icon: Icons.credit_card_outlined,
    tags: <String>['loan', 'emi', 'interest', 'tenure', 'amortisation'],
  ),

  // ── Currency ──────────────────────────────────────────────────────────────
  AppCalculatorMeta(
    id: 'currency',
    name: 'Currency Converter',
    description: 'Convert between 11 major trading currencies.',
    category: AppCalculatorCategory.currency,
    icon: Icons.currency_exchange_outlined,
    tags: <String>['forex', 'inr', 'usd', 'exchange rate', 'convert'],
  ),
  AppCalculatorMeta(
    id: 'pip_value',
    name: 'Pip Value',
    description: 'Rupee value of one pip for a forex lot.',
    category: AppCalculatorCategory.currency,
    icon: Icons.straighten_outlined,
    tags: <String>['forex', 'pip', 'lot', 'usdinr'],
  ),

  // ── Tax ───────────────────────────────────────────────────────────────────
  AppCalculatorMeta(
    id: 'stcg',
    name: 'Short-Term Gains Tax',
    description: 'STCG at 15% on equity held under a year.',
    category: AppCalculatorCategory.tax,
    icon: Icons.bolt_outlined,
    tags: <String>['stcg', 'tax', '15 percent', 'equity'],
  ),
  AppCalculatorMeta(
    id: 'ltcg',
    name: 'Long-Term Gains Tax',
    description: 'LTCG at 10% on gains above the ₹1 lakh exemption.',
    category: AppCalculatorCategory.tax,
    icon: Icons.hourglass_full_outlined,
    tags: <String>['ltcg', 'tax', 'exemption', '1 lakh', 'equity'],
  ),
  AppCalculatorMeta(
    id: 'turnover',
    name: 'Trading Turnover',
    description: 'Turnover for audit thresholds under section 44AB.',
    category: AppCalculatorCategory.tax,
    icon: Icons.summarize_outlined,
    tags: <String>['turnover', 'audit', '44ab', 'itr', 'presumptive'],
  ),
];

/// Metadata for [id]. Throws when the id is not in [kAllCalculators] — a
/// missing entry is a programming error, not a runtime condition.
AppCalculatorMeta calculatorMetaById(String id) =>
    kAllCalculators.firstWhere((AppCalculatorMeta m) => m.id == id);
