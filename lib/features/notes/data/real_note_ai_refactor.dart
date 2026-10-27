import 'package:flutter/foundation.dart';
import 'package:tradex/core/ai/unified_ai_service.dart';
import 'package:tradex/core/app-ui/app_ui.dart';
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

    const systemPrompt = '''
You are hejournal.in Copilot, an elite quantitative financial analyst and disciplined trading performance coach.
Your task is to refine, enhance, or restructure the trader's note content according to their instructions.
Guidelines:
- Return ONLY the clean, formatted Markdown output without conversational preambles or chat greetings.
- Maintain all price levels, ratios, numbers, tickers, and percentages exactly.
- Apply high-signal trading formatting (tables, checklists, bulleted frameworks).
- Adhere strictly to the requested instruction.
''';

    final prompt =
        '''
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
      debugPrint(
        '[RealNoteAiRefactor] AI error: $e. Using local dynamic fallback.',
      );
    }

    // Dynamic trading fallback
    return _generateDynamicAnalysis(
      selectedText: cleanText,
      noteType: noteType,
      contextTitle: contextTitle,
      instruction: instruction,
    );
  }

  String _generateDynamicAnalysis({
    required String selectedText,
    required AppNoteType noteType,
    String? contextTitle,
    String? instruction,
  }) {
    final lines = selectedText
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();
    if (lines.isEmpty) return selectedText;

    final ask = (instruction ?? '').toLowerCase();

    // 1. Checklist request
    if (ask.contains('checklist') || ask.contains('check list')) {
      return lines
          .map((l) => '- [ ] ${_sentence(l).replaceAll(RegExp(r'\.$'), '')}')
          .join('\n');
    }

    // 2. Critique / Invalidation analysis
    if (ask.contains('critique') ||
        ask.contains('invalidate') ||
        ask.contains('risk')) {
      final buffer = StringBuffer();
      buffer.writeln('### Technical Assessment & Thesis Critique');
      buffer.writeln();
      buffer.writeln(_tidy(lines));
      buffer.writeln();
      buffer.writeln('#### Invalidation Conditions & Risk Triggers');
      for (final line in lines) {
        if (RegExp(r'\d+').hasMatch(line)) {
          final preview = line.length > 60
              ? '${line.substring(0, 57)}...'
              : line;
          buffer.writeln(
            '- [ ] Adverse break beyond key structural level identified in: *"$preview"*',
          );
        }
      }
      buffer.writeln(
        '- [ ] Volume fails to confirm breakout on 15m/1H candle close',
      );
      buffer.writeln(
        '- [ ] Volatility index (VIX/India VIX) spikes above comfort threshold',
      );
      buffer.writeln(
        '- [ ] Risk-to-reward degrades below minimum 1:2 threshold',
      );
      return buffer.toString();
    }

    // 3. Trade Plan request
    if (ask.contains('plan') || noteType == AppNoteType.plan) {
      final buffer = StringBuffer();
      final title = contextTitle?.trim().isNotEmpty ?? false
          ? contextTitle!.trim()
          : 'Systematic Execution Plan';
      buffer.writeln('## $title');
      buffer.writeln();
      buffer.writeln('**Core Thesis:** ${_sentence(lines.first)}');
      buffer.writeln();
      buffer.writeln('| Execution Step | Parameter / Observation | Protocol |');
      buffer.writeln('| :--- | :--- | :--- |');
      for (int i = 0; i < lines.length; i++) {
        final l = lines[i];
        final clean = l.replaceAll('|', '-');
        buffer.writeln('| Step ${i + 1} | $clean | Verified before trigger |');
      }
      buffer.writeln();
      buffer.writeln('### Pre-Trade Verification Checklist');
      for (final l in lines) {
        buffer.writeln(
          '- [ ] Confirmed ${_sentence(l).replaceAll(RegExp(r'\.$'), '')}',
        );
      }
      return buffer.toString();
    }

    // 4. Summary request
    if (ask.contains('summar')) {
      if (lines.length == 1) return _tidy(lines);
      final bullets = lines.skip(1).map((l) => '- ${_sentence(l)}').join('\n');
      return '> **Executive Summary:** ${_sentence(lines.first)}\n\n$bullets';
    }

    // Default: format prose cleanly and preserve markdown
    return _tidy(lines);
  }

  String _tidy(List<String> lines) => lines
      .map((String l) => _looksLikeMarkup(l) ? l : _sentence(l))
      .join('\n\n');

  bool _looksLikeMarkup(String line) =>
      RegExp(r'^(#{1,6} |[-*+] |\d+[.)] |> |\||```|\$\$)').hasMatch(line);

  String _sentence(String line) {
    final String trimmed = line.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (trimmed.isEmpty) return trimmed;
    final String capped = trimmed[0].toUpperCase() + trimmed.substring(1);
    return RegExp(r'[.!?:;]$').hasMatch(capped) ? capped : '$capped.';
  }
}
