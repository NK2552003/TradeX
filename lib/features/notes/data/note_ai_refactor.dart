import 'package:alphajournal/core/app-ui/app_ui.dart';
import 'real_note_ai_refactor.dart';

/// Rewrites a selected passage of a note.
///
/// Backend hand-off: the production implementation posts
/// `{selectedText, contextTitle, instruction, noteType}` to the
/// `note-ai-refactor` Edge Function and returns its `enhanced` string. Swap it
/// in through [NoteAiScope.override] — the editor only ever talks to this
/// interface, so no widget changes.
abstract class NoteAiRefactor {
  Future<String> enhance({
    required String selectedText,
    required AppNoteType noteType,
    String? contextTitle,
    String? instruction,
  });
}

/// On-device stand-in used until the Edge Function is live.
///
/// Deliberately mechanical rather than pretending to be a model: it tidies
/// whitespace, promotes loose lines into the structure the instruction asked
/// for, and leaves every number the writer typed untouched. That makes the
/// editor's AI path fully exercisable — selection tracking, the refactor bar,
/// the custom-prompt sheet, the undo stack — without inventing trading advice
/// nobody asked for.
class NoteAiRefactorDemo implements NoteAiRefactor {
  const NoteAiRefactorDemo();

  @override
  Future<String> enhance({
    required String selectedText,
    required AppNoteType noteType,
    String? contextTitle,
    String? instruction,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 650));
    final List<String> lines = selectedText
        .split('\n')
        .map((String l) => l.trim())
        .where((String l) => l.isNotEmpty)
        .toList();
    if (lines.isEmpty) return selectedText;

    final String ask = (instruction ?? '').toLowerCase();
    if (ask.contains('checklist') || ask.contains('check list')) {
      return lines.map(_asChecklistItem).join('\n');
    }
    if (ask.contains('bullet') || ask.contains('list')) {
      return lines.map((String l) => _asBullet(l)).join('\n');
    }
    if (ask.contains('plan')) {
      return _tradePlan(lines, contextTitle);
    }
    if (ask.contains('critique') || ask.contains('invalidate')) {
      return '${_tidy(lines)}\n\n'
          '**What would make this wrong**\n\n'
          '- [ ] The level fails to hold on a retest\n'
          '- [ ] Volume never confirms the move\n'
          '- [ ] The catalyst lands and price ignores it\n';
    }
    if (ask.contains('summar')) {
      return lines.length == 1
          ? _tidy(lines)
          : '> ${_sentence(lines.first)}\n\n${lines.skip(1).map(_asBullet).join('\n')}';
    }
    if (ask.contains('review')) {
      return '### What happened\n\n${_tidy(lines)}\n\n'
          '### What I would repeat\n\n- \n\n'
          '### What I would change\n\n- [ ] \n';
    }
    // No instruction: the quick pass. Tighten the prose and keep the shape.
    return _tidy(lines);
  }

  String _tidy(List<String> lines) => lines
      .map((String l) => _looksLikeMarkup(l) ? l : _sentence(l))
      .join('\n\n');

  String _tradePlan(List<String> lines, String? contextTitle) =>
      '## ${contextTitle?.trim().isNotEmpty ?? false ? contextTitle!.trim() : 'Trade plan'}\n\n'
      '**Thesis** — ${_sentence(lines.first)}\n\n'
      '| Field | Value |\n| --- | --- |\n'
      '| Entry |  |\n| Stop loss |  |\n| Target |  |\n| R:R |  |\n\n'
      '${lines.length > 1 ? '**Notes**\n\n${lines.skip(1).map(_asBullet).join('\n')}\n' : ''}';

  String _asBullet(String line) =>
      _looksLikeMarkup(line) ? line : '- ${_sentence(line)}';

  String _asChecklistItem(String line) => _looksLikeMarkup(line)
      ? line
      : '- [ ] ${_sentence(line).replaceFirst(RegExp(r'\.$'), '')}';

  /// Headings, existing list items, table rows and fences are already
  /// structured — rewriting them would break the document.
  bool _looksLikeMarkup(String line) =>
      RegExp(r'^(#{1,6} |[-*+] |\d+[.)] |> |\||```|\$\$)').hasMatch(line);

  String _sentence(String line) {
    final String trimmed = line.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (trimmed.isEmpty) return trimmed;
    final String capped = trimmed[0].toUpperCase() + trimmed.substring(1);
    return RegExp(r'[.!?:;]$').hasMatch(capped) ? capped : '$capped.';
  }
}

/// The single place the editor reaches the refactor service.
class NoteAiScope {
  const NoteAiScope._();

  static NoteAiRefactor? _override;

  static NoteAiRefactor get service => _override ?? const RealNoteAiRefactor();

  static bool get isDemo =>
      _override != null && _override is NoteAiRefactorDemo;

  static void override(NoteAiRefactor? replacement) => _override = replacement;
}
