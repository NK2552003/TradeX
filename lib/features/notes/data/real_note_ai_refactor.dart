import 'package:flutter/foundation.dart';
import 'package:tradex/core/ai/unified_ai_service.dart';
import 'package:tradex/core/app-ui/app_ui.dart';
import 'package:tradex/core/config/env_config.dart';
import 'package:tradex/core/config/supabase_config.dart';
import 'note_ai_refactor.dart';

class RealNoteAiRefactor implements NoteAiRefactor {
  const RealNoteAiRefactor();

  @override
  Future<String> enhance({
    required String selectedText,
    required AppNoteType noteType,
    String? contextTitle,
    String? instruction,
  }) async {
    final cleanText = selectedText.trim();
    if (cleanText.isEmpty) return selectedText;

    // 1. Authenticated session check
    if (SupabaseConfig.isConfigured) {
      final session = SupabaseConfig.client?.auth.currentSession;
      final user = SupabaseConfig.client?.auth.currentUser;
      if (session == null || user == null || session.accessToken.isEmpty) {
        throw StateError('Sign in required to use AI note refactoring.');
      }
    }

    // 2. Invoke deployed note-ai-refactor Edge Function
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
            return enhanced;
          }
        }
        if (res.data is Map) {
          final data = res.data as Map;
          if (data['error'] != null) {
            throw StateError(data['error'].toString());
          }
        }
        if (res.status == 401) {
          throw StateError('Sign in required to use AI note refactoring.');
        }
        if (res.status == 429) {
          throw StateError(
            'AI monthly quota exceeded. Upgrade your plan for more refactoring requests.',
          );
        }
      } catch (e) {
        if (e is StateError) rethrow;
        debugPrint(
          '[RealNoteAiRefactor] Edge function note-ai-refactor call error: $e',
        );
      }
    }

    // 3. Fallback to client-side AI providers if configured
    if (EnvConfig.hasAiKey) {
      const systemPrompt = '''
You are alphajournal Copilot, an elite quantitative financial analyst and disciplined trading performance coach.
Your task is to refine, enhance, or restructure the trader's note content according to their instructions.
Guidelines:
- Return ONLY the clean, formatted Markdown output without conversational preambles or chat greetings.
- Maintain all price levels, ratios, numbers, tickers, and percentages exactly.
- Apply high-signal trading formatting (tables, checklists, bulleted frameworks).
- Adhere strictly to the requested instruction.
''';

      final prompt = '''
Context:
- Note Title: ${contextTitle ?? 'Trading Note'}
- Note Type: ${noteType.label}
- Instruction: ${instruction ?? 'Refine, polish, and structure into clear actionable trading notes'}

Selected Note Passage:
"""
$cleanText
"""
''';

      try {
        final enhanced = await UnifiedAiService.instance.complete(
          prompt: prompt,
          systemPrompt: systemPrompt,
        );
        if (enhanced.trim().isNotEmpty) {
          return enhanced.trim();
        }
      } catch (e) {
        debugPrint('[RealNoteAiRefactor] Client AI provider error: $e');
      }
    }

    // 4. Do not silently return local regex output as simulated AI.
    // Instead throw a descriptive StateError when the authenticated service is unreachable.
    throw StateError(
      'AI refactoring service is currently unavailable. Please verify your connection or try again later.',
    );
  }
}

/// Alias for Edge Note AI Refactor per backend hand-off contract
typedef EdgeNoteAiRefactor = RealNoteAiRefactor;
