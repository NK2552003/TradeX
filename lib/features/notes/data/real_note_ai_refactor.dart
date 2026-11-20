import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:alphajournal/core/ai/unified_ai_service.dart';
import 'package:alphajournal/core/app-ui/app_ui.dart';
import 'package:alphajournal/core/config/customer_limitations.dart';
import 'package:alphajournal/core/config/env_config.dart';
import 'package:alphajournal/core/config/supabase_config.dart';
import 'package:alphajournal/features/copilot/models/research_router.dart';
import 'package:alphajournal/features/settings/data/repositories/ai_settings_repository.dart';
import 'note_ai_refactor.dart';

class RealNoteAiRefactor implements NoteAiRefactor {
  const RealNoteAiRefactor();

  static final RegExp _researchTrigger = RegExp(
    r'\b(research|latest|news|verify|fact[\s-]?check|catalyst|earnings|macro|compare|sources?|cite|web|current|today|price|valuation)\b',
    caseSensitive: false,
  );

  static String _cleanNoteMarkdown(String raw) {
    var out = raw.trim();
    // Strip trailing ```json followups blocks if the gateway returns them.
    out = out.replaceFirst(
      RegExp(r'\n*```(?:json)?\s*\[\s*"[\s\S]*?"\s*\]\s*```\s*$'),
      '',
    );
    // Unwrap if the entire answer was wrapped in a ```markdown fence.
    final fence = RegExp(r'^```(?:markdown|md)?\s*\n([\s\S]*?)\n```\s*$');
    final match = fence.firstMatch(out);
    if (match != null) {
      out = (match.group(1) ?? out).trim();
    }
    return out.trim();
  }

  @override
  Future<String> enhance({
    required String selectedText,
    required AppNoteType noteType,
    String? contextTitle,
    String? instruction,
  }) async {
    final cleanText = selectedText.trim();
    if (cleanText.isEmpty) return selectedText;

    if (CustomerLimitations.isAiQuotaExhausted()) {
      throw StateError(
        'AI monthly quota exceeded. Upgrade your plan for more refactoring requests.',
      );
    }

    // 1. Authenticated session check
    if (SupabaseConfig.isConfigured) {
      final session = SupabaseConfig.client?.auth.currentSession;
      final user = SupabaseConfig.client?.auth.currentUser;
      if (session == null || user == null || session.accessToken.isEmpty) {
        throw StateError('Sign in required to use AI note refactoring.');
      }
    }

    final effectiveInstruction = (instruction ?? '').trim().isNotEmpty
        ? instruction!.trim()
        : 'Refine, polish, and structure into clear, high-signal trading notes';
    final bool allowWebSearch =
        _researchTrigger.hasMatch(effectiveInstruction);
    final aiSettings = AiSettingsRepositoryImpl.instance.cachedSettings;
    final responseStyle = aiSettings.responseStyle;
    final citationsStyle = aiSettings.citationsStyle;

    // 2. Primary path: route through the same Copilot ai-gateway pipeline as
    // `/ai_copilot` so selection edits receive identical structured Markdown
    // formatting, research routing, and live quota accounting.
    if (SupabaseConfig.isConfigured || EnvConfig.hasAiKey) {
      final systemBuffer = StringBuffer('''
You are AlphaJournal Copilot (Atlas), an institutional-grade financial analyst, research writer, and disciplined trading performance coach.
Rewrite, enhance, or expand the trader's selected note passage using the exact same Perplexity-style structured Markdown and visual cards used in AlphaJournal Copilot:
- Return ONLY the clean, formatted Markdown replacement ready to insert directly into the note — no conversational preambles, no greetings, and no trailing follow-up JSON arrays.
- Preserve every price level, ratio, ticker, date, quantity, and percentage accurately.
- Automatically select and include the most fitting fenced visual cards for the content whenever structured data, setups, metrics, risks, comparisons, or checklists are present: `company`, `person`, `news`, `links`, `video`, `market_pulse`, `earnings_calendar`, `scenarios`, `backtest`, `portfolio`, `filing`, `wiki`, `risk_plan`, `workflow`, `compare`, `timeline`, `setup`, `verdict`, `factbox`, `faq`, `checklist`, `quote`, `earnings`, `financials`, `macro`, `ratings`, `screener`, `sentiment`, `product`, `media`, `formula`, `chart`, `kpi`, and `research_panel`.
- Combine cards naturally with crisp headings (`##` / `###`), callout blockquotes (`>`), Markdown tables, checklists (`- [ ]`), and bullet frameworks.
- Keep dollar currency amounts as plain text (e.g. \$1.5 trillion, \$83) — only use LaTeX math for genuine equations.
- Adhere strictly to the user's requested instruction.
''');
      if (responseStyle == 'concise') {
        systemBuffer.writeln(
          '- Style: CONCISE — lead immediately with key metrics/answer in 2-4 crisp bullets and compact visual cards.',
        );
      } else if (responseStyle == 'detailed') {
        systemBuffer.writeln(
          '- Style: DETAILED — provide thorough institutional sections, breakdown tables, bull/bear scenarios, risks, and rich visual cards.',
        );
      }
      if (allowWebSearch) {
        systemBuffer.writeln(
          citationsStyle == 'footnotes'
              ? '- Citations: use numbered inline markers [1], [2] and end with a numbered Sources list with real [Source](url) links.'
              : '- Citations: embed descriptive inline markdown links [Source](url) next to supported facts.',
        );
      }
      systemBuffer.writeln(
        ResearchRouter.select('$effectiveInstruction\n$cleanText').instructions,
      );

      final prompt =
          '''
Context:
- Note Title: ${contextTitle ?? 'Trading Note'}
- Note Type: ${noteType.label}
- Instruction: $effectiveInstruction

Selected Note Passage:
"""
$cleanText
"""
''';

      try {
        final enhanced = await UnifiedAiService.instance.complete(
          prompt: prompt,
          systemPrompt: systemBuffer.toString(),
          maxTokens: responseStyle == 'concise' ? 1800 : 4096,
          mode: allowWebSearch ? 'search' : 'auto',
          allowWebSearch: allowWebSearch,
          allowLocalFallback: false,
        );
        final cleaned = _cleanNoteMarkdown(enhanced);
        if (cleaned.isNotEmpty) {
          return cleaned;
        }
      } on StateError catch (e) {
        if (CustomerLimitations.isQuotaErrorMessage(e.message) ||
            e.message.toLowerCase().contains('sign in')) {
          rethrow;
        }
        debugPrint('[RealNoteAiRefactor] Copilot gateway error: $e');
      } catch (e) {
        debugPrint('[RealNoteAiRefactor] Copilot gateway error: $e');
      }
    }

    // 3. Fallback: invoke legacy note-ai-refactor Edge Function if ai-gateway failed
    if (SupabaseConfig.isConfigured) {
      try {
        final payload = <String, dynamic>{
          'selectedText': cleanText,
          'noteType': noteType.wireId,
        };
        if (contextTitle != null) payload['contextTitle'] = contextTitle;
        if (instruction != null) payload['instruction'] = instruction;

        final res = await SupabaseConfig.client!.functions.invoke(
          'note-ai-refactor',
          body: payload,
        );
        if (res.status == 200 && res.data is Map) {
          final data = res.data as Map;
          final enhanced = data['enhanced']?.toString().trim();
          if (enhanced != null && enhanced.isNotEmpty) {
            return _cleanNoteMarkdown(enhanced);
          }
        }
        if (res.status == 401) {
          throw StateError('Sign in required to use AI note refactoring.');
        }
        if (res.status == 429) {
          CustomerLimitations.markAiQuotaExhausted();
          throw StateError(
            'AI monthly quota exceeded. Upgrade your plan for more refactoring requests.',
          );
        }
        if (res.data is Map && (res.data as Map)['error'] != null) {
          throw StateError((res.data as Map)['error'].toString());
        }
      } on FunctionException catch (fe) {
        debugPrint(
          '[RealNoteAiRefactor] Edge function FunctionException: status=${fe.status}, details=${fe.details}',
        );
        if (fe.status == 401) {
          throw StateError('Sign in required to use AI note refactoring.');
        }
        if (fe.status == 429) {
          CustomerLimitations.markAiQuotaExhausted();
          throw StateError(
            'AI monthly quota exceeded. Upgrade your plan for more refactoring requests.',
          );
        }
      } on StateError {
        rethrow;
      } catch (e) {
        debugPrint('[RealNoteAiRefactor] Edge function transport error: $e');
      }
    }

    // 4. Do not silently return local regex output as simulated AI.
    throw StateError(
      'AI refactoring service is currently unavailable. Please verify your connection or try again later.',
    );
  }
}

/// Alias for Edge Note AI Refactor per backend hand-off contract
typedef EdgeNoteAiRefactor = RealNoteAiRefactor;
