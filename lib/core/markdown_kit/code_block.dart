import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_highlight/flutter_highlight.dart';
import 'package:flutter_highlight/themes/atom-one-dark.dart';
import 'package:flutter_highlight/themes/atom-one-light.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
// Side-effect import: registers every bundled `highlight` language (dart,
// python, js, java, kotlin, swift, sql, bash, json, yaml, and 150+ more) so
// any ```lang fenced block can be syntax-highlighted without maintaining a
// per-language registration list.
// ignore: unused_import
import 'package:highlight/languages/all.dart';
import 'package:markdown/markdown.dart' as md;
import 'package:tradex/core/app-ui/app_ui.dart';
// ignore: unnecessary_import
import 'package:tradex/core/flutter-ui/flutter_ui.dart';
import 'package:tradex/core/app-ui/motion/ai_typing_indicator.dart';
import 'research/typing_cursor_syntax.dart';
import 'package:tradex/core/markdown_kit/chart_block.dart';
import 'package:tradex/core/markdown_kit/flowchart/flowchart_view.dart';
import 'package:tradex/core/markdown_kit/perplexity_card_block.dart';
import 'package:tradex/core/markdown_kit/perplexity_domain_cards.dart';
import 'package:tradex/core/markdown_kit/perplexity_parser.dart';
import 'package:tradex/core/utils/image_export.dart';

/// Registers with [MarkdownBody]/[Markdown] via the `builders: {'pre': ...}`
/// hook. Routes fenced code blocks to the right renderer by language tag:
/// ```mermaid``` → an interactive flowchart/diagram, ```chart``` → a native
/// chart, Perplexity entity/research blocks → [PerplexityCardBlock],
/// everything else → a syntax-highlighted code block with a copy button.
class RichCodeBlockBuilder extends MarkdownElementBuilder {
  RichCodeBlockBuilder({
    required this.dark,
    this.onOpenRef,
    this.onTapUrl,
    this.onPromptTap,
  });

  final bool dark;
  final PerplexityOpenRefCallback? onOpenRef;
  final PerplexityOpenUrlCallback? onTapUrl;
  final PerplexityPromptCallback? onPromptTap;

  // `pre` is a block-level tag. Without this override some flutter_markdown
  // versions never hand the element to a custom builder at all and silently
  // fall back to the default code-block renderer.
  @override
  bool isBlockElement() => true;

  @override
  Widget? visitElementAfter(md.Element element, TextStyle? preferredStyle) {
    final md.Element? code = element.children
        ?.whereType<md.Element>()
        .firstOrNull;
    if (code == null || code.tag != 'code') return null;

    final String cls = code.attributes['class'] ?? '';
    final String rawLang = cls.replaceFirst('language-', '').trim();
    final String langKey = rawLang.toLowerCase();
    final bool typing = code.textContent.contains(typingCursorMarker);
    final String source = code.textContent.replaceAll(typingCursorMarker, '');
    if (source.trim().isEmpty) return null;

    if (langKey == 'mermaid' || langKey == 'flowchart') {
      return _MermaidBlock(source: source.trim(), dark: dark);
    }
    if (PerplexityBlockTags.followUpTags.contains(langKey)) {
      final List<String> questions = PerplexityAnswerParser.parseFollowUps(
        source.trim(),
      );
      if (questions.isNotEmpty) {
        return _FollowUpsBlock(
          questions: questions,
          onPromptTap: onPromptTap,
        );
      }
    }
    if (PerplexityBlockTags.searchStepTags.contains(langKey)) {
      final List<PerplexitySearchStep> steps =
          PerplexityAnswerParser.parseSearchSteps(source.trim());
      if (steps.isNotEmpty) {
        return _SearchStepsBlock(steps: steps);
      }
    }
    if (PerplexityBlockTags.perplexityCards.contains(langKey) ||
        (!PerplexityBlockTags.chartAndDiagramTags.contains(langKey) &&
            isStructuredPerplexityJson(source.trim()))) {
      return PerplexityCardBlock(
        tag: PerplexityBlockTags.perplexityCards.contains(langKey)
            ? langKey
            : (isResearchPanelJson(source.trim()) ? 'research_panel' : 'card'),
        spec: source.trim(),
        onOpenRef: onOpenRef,
        onTapUrl: onTapUrl,
        onPromptTap: onPromptTap,
      );
    }
    const Set<String> chartFenceTags = <String>{
      'chart',
      'graph',
      'plot',
      'bar',
      'line',
      'area',
      'combo',
      'pie',
      'donut',
      'candle',
      'candles',
      'ohlc',
      'waterfall',
      'barlist',
      'ranking',
      'kpi',
      'metrics',
      'spark',
      'sparkline',
    };
    if (chartFenceTags.contains(langKey)) {
      final String? defaultType =
          (langKey == 'chart' || langKey == 'graph' || langKey == 'plot')
          ? null
          : langKey;
      return ChartBlock(spec: source.trim(), defaultType: defaultType);
    }
    return _CodeBlock(
      typing: typing,
      source: source.trimRight(),
      language: _canonicalLanguage(rawLang),
      displayLanguage: rawLang,
      dark: dark,
    );
  }
}

/// Returns true when [raw] is a JSON object matching the [ResearchPanel]
/// payload shape (`columns` + `rows`, or `format` with `summary`/`rows`),
/// so AI responses or saved notes using ```` ```json ```` or bare fences
/// render as a rich research table card instead of raw JSON.
bool isResearchPanelJson(String raw) {
  final String trimmed = raw.trim();
  if (!trimmed.startsWith('{') || !trimmed.endsWith('}')) return false;
  try {
    final dynamic decoded = jsonDecode(trimmed);
    if (decoded is! Map) return false;
    final bool hasTable =
        decoded['columns'] is List &&
        (decoded['columns'] as List).isNotEmpty &&
        decoded['rows'] is List;
    final bool hasFormat =
        decoded['format'] is String &&
        (decoded['summary'] is String ||
            decoded['rows'] is List ||
            decoded['evidence'] is List);
    return hasTable || hasFormat;
  } catch (_) {
    return false;
  }
}

/// Returns true when [raw] is a JSON object matching [ResearchPanel] or a
/// structured [PerplexityCardBlock] domain schema, so ```` ```json ```` or
/// untagged fences render as rich cards instead of raw JSON.
bool isStructuredPerplexityJson(String raw) {
  if (isResearchPanelJson(raw)) return true;
  final String trimmed = raw.trim();
  if (!trimmed.startsWith('{') || !trimmed.endsWith('}')) return false;
  try {
    final dynamic decoded = jsonDecode(trimmed);
    if (decoded is! Map) return false;
    return decoded.containsKey('scenarios') ||
        decoded.containsKey('cases') ||
        (decoded.containsKey('entry') && decoded.containsKey('stopLoss')) ||
        decoded.containsKey('leftItems') ||
        decoded.containsKey('rightItems') ||
        decoded.containsKey('entities') ||
        decoded.containsKey('quadrants') ||
        decoded.containsKey('equityCurve') ||
        decoded.containsKey('profitFactor') ||
        decoded.containsKey('holdings') ||
        decoded.containsKey('allocations') ||
        (decoded.containsKey('accountSize') && decoded.containsKey('riskPct')) ||
        decoded.containsKey('indicators') ||
        decoded.containsKey('releases') ||
        decoded.containsKey('targetMean') ||
        decoded.containsKey('upgrades') ||
        decoded.containsKey('putCallRatio') ||
        decoded.containsKey('fearGreed') ||
        decoded.containsKey('formula') ||
        decoded.containsKey('equation') ||
        decoded.containsKey('marketCap') ||
        decoded.containsKey('peRatio') ||
        (decoded.containsKey('symbol') && decoded.containsKey('price')) ||
        decoded.containsKey('netWorth') ||
        decoded.containsKey('bio') ||
        decoded.containsKey('articles') ||
        decoded.containsKey('filingType') ||
        decoded.containsKey('videoUrl') ||
        decoded.containsKey('videos') ||
        decoded.containsKey('facts') ||
        decoded.containsKey('quote');
  } catch (_) {
    return false;
  }
}

/// Maps the shorthand/alias people actually type after a fence (```html,
/// ```js, ```sh, ...) to the grammar name the `highlight` package registers
/// it under, so every common alias — not just the canonical name — lights
/// up correctly. This is what makes ```html fenced blocks highlight like
/// GitHub renders them (tags, attributes, embedded script/style) instead of
/// falling back to plain text.
String _canonicalLanguage(String lang) {
  const Map<String, String> aliases = <String, String>{
    'html': 'xml',
    'htm': 'xml',
    'xhtml': 'xml',
    'svg': 'xml',
    'vue': 'xml',
    'sh': 'bash',
    'shell': 'bash',
    'zsh': 'bash',
    'js': 'javascript',
    'mjs': 'javascript',
    'cjs': 'javascript',
    'jsx': 'javascript',
    'ts': 'typescript',
    'tsx': 'typescript',
    'py': 'python',
    'py3': 'python',
    'rb': 'ruby',
    'kt': 'kotlin',
    'kts': 'kotlin',
    'cs': 'csharp',
    'c++': 'cpp',
    'cc': 'cpp',
    'h': 'cpp',
    'hpp': 'cpp',
    'yml': 'yaml',
    'md': 'markdown',
    'ps1': 'powershell',
    'dockerfile': 'dockerfile',
    'plaintext': '',
    'text': '',
    'txt': '',
  };
  final String key = lang.toLowerCase();
  return aliases[key] ?? key;
}

/// Shared header chrome for every fenced block (code, mermaid): a themed
/// container with a rounded top strip holding a label chip + icon on the
/// left and up to a few icon actions on the right, a hairline divider, then
/// whatever [body] renders below it. Code blocks and flowchart blocks share
/// this exact frame so they read as one visual family that follows the
/// app's live theme (colors, radii) rather than fixed hex values.
class _FencedBlockChrome extends StatelessWidget {
  const _FencedBlockChrome({
    required this.icon,
    required this.label,
    required this.actions,
    required this.body,
    this.bodyPadding = EdgeInsets.zero,
  });

  final IconData icon;
  final String label;
  final List<Widget> actions;
  final Widget body;
  final EdgeInsets bodyPadding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(
        vertical: context.sp(context.ui.spacing.sm),
      ),
      child: UiCard(
        variant: UiCardVariant.subtle,
        padding: EdgeInsets.all(context.sp(context.ui.spacing.sm)),
        titleWidget: UiBadge(
          label: label,
          icon: icon,
          variant: UiBadgeVariant.soft,
          size: UiSize.xs,
        ),
        trailing: Wrap(children: actions),
        headerDivider: true,
        child: Padding(padding: bodyPadding, child: body),
      ),
    );
  }
}

/// A small icon-only action button matching the fenced-block header style
/// (quiet by default, themed hover/press state, compact hit target).
class _ChromeIconButton extends StatelessWidget {
  const _ChromeIconButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.color,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return UiIconButton(
      icon: icon,
      size: UiSize.sm,
      tooltip: tooltip,
      intent: color == context.ui.colors.bullish
          ? UiIntent.success
          : UiIntent.neutral,
      onPressed: onPressed,
    );
  }
}

/// A syntax-highlighted, copyable fenced code block. Chrome (background,
/// border, label chip) is driven entirely by the live [UiTheme] — including
/// the person's chosen accent — rather than fixed colors, so it always
/// matches the rest of the app; only the token colors inside the code come
/// from a dedicated syntax theme, since those need their own fixed palette
/// to stay readable and distinguishable regardless of the accent color.
class _FollowUpsBlock extends StatelessWidget {
  const _FollowUpsBlock({required this.questions, this.onPromptTap});

  final List<String> questions;
  final ValueChanged<String>? onPromptTap;

  @override
  Widget build(BuildContext context) {
    final UiTheme theme = context.ui;
    return Padding(
      padding: EdgeInsets.symmetric(vertical: context.sp(theme.spacing.xs)),
      child: UiCard(
        variant: UiCardVariant.subtle,
        title: 'Related Questions',
        child: Wrap(
          spacing: context.sp(theme.spacing.xs),
          runSpacing: context.sp(theme.spacing.xs),
          children: <Widget>[
            for (final String q in questions)
              UiButton(
                label: q,
                leadingIcon: onPromptTap != null
                    ? Icons.subdirectory_arrow_right_rounded
                    : Icons.content_copy_outlined,
                size: UiSize.xs,
                variant: UiVariant.soft,
                onPressed: () {
                  if (onPromptTap != null) {
                    onPromptTap!(q);
                  } else {
                    Clipboard.setData(ClipboardData(text: q));
                    UiToast.info(
                      context,
                      title: 'Copied prompt',
                      message: q,
                    );
                  }
                },
              ),
          ],
        ),
      ),
    );
  }
}

class _SearchStepsBlock extends StatelessWidget {
  const _SearchStepsBlock({required this.steps});

  final List<PerplexitySearchStep> steps;

  @override
  Widget build(BuildContext context) {
    final UiTheme theme = context.ui;
    return Padding(
      padding: EdgeInsets.symmetric(vertical: context.sp(theme.spacing.xs)),
      child: UiAccordion(
        sections: <UiAccordionSection>[
          UiAccordionSection(
            title: 'Research Steps (${steps.length})',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                for (int i = 0; i < steps.length; i++) ...<Widget>[
                  if (i > 0) UiGap.v(theme.spacing.xs),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Icon(
                        Icons.check_circle_outline_rounded,
                        size: context.sz(14),
                        color: theme.colors.bullish,
                      ),
                      UiGap.h(theme.spacing.xs),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              steps[i].title,
                              style: context.uiText.body.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            if (steps[i].detail.isNotEmpty)
                              Text(
                                steps[i].detail,
                                style: context.uiText.caption.copyWith(
                                  color: theme.colors.foregroundSubtle,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CodeBlock extends StatefulWidget {
  const _CodeBlock({
    required this.source,
    required this.language,
    required this.displayLanguage,
    required this.dark,
    this.typing = false,
  });

  final String source;
  final String language;
  final String displayLanguage;
  final bool dark;
  final bool typing;

  @override
  State<_CodeBlock> createState() => _CodeBlockState();
}

class _CodeBlockState extends State<_CodeBlock> {
  bool _copied = false;

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: widget.source));
    if (!mounted) return;
    setState(() => _copied = true);
    UiToast.show(context, title: 'Copied', intent: UiIntent.success);
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _copied = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.uiColors;
    final String label = widget.displayLanguage.isEmpty
        ? 'code'
        : widget.displayLanguage.toLowerCase();
    return _FencedBlockChrome(
      icon: Icons.code_rounded,
      label: label,
      bodyPadding: EdgeInsets.zero,
      actions: [
        _ChromeIconButton(
          icon: _copied ? Icons.check_rounded : Icons.copy_outlined,
          tooltip: 'Copy code',
          color: _copied ? colors.bullish : null,
          onPressed: _copy,
        ),
      ],
      body: ClipRRect(
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(11)),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: _highlighted(context),
        ),
      ),
    );
  }

  Widget _highlighted(BuildContext context) {
    final style = TextStyle(
      fontFamily: 'monospace',
      fontSize: 13,
      height: 1.5,
      color: context.uiColors.foreground,
    );
    if (widget.typing) {
      return Padding(
        padding: EdgeInsets.symmetric(
          horizontal: context.sp(context.ui.spacing.sm),
        ),
        child: Text.rich(
          TextSpan(
            style: style,
            text: widget.source,
            children: [
              WidgetSpan(
                alignment: PlaceholderAlignment.middle,
                child: AiTypingCursor(style: style),
              ),
            ],
          ),
        ),
      );
    }
    if (widget.language.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: SelectableText(widget.source, style: style),
      );
    }
    try {
      // The bundled syntax theme supplies token colors only; its own
      // background is stripped so the surrounding themed chrome (which
      // follows the app's live theme/accent) shows through instead of a
      // hardcoded editor-theme background that could clash with it.
      final Map<String, TextStyle> base = widget.dark
          ? atomOneDarkTheme
          : atomOneLightTheme;
      final Map<String, TextStyle> transparent = <String, TextStyle>{
        for (final entry in base.entries) entry.key: entry.value,
        'root': (base['root'] ?? const TextStyle()).copyWith(
          backgroundColor: Colors.transparent,
        ),
      };
      return HighlightView(
        widget.source,
        language: widget.language,
        theme: transparent,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        textStyle: style,
      );
    } catch (_) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: SelectableText(widget.source, style: style),
      );
    }
  }
}

/// A mermaid flowchart/diagram block with a header offering fullscreen
/// pan+zoom viewing and a PNG download/share.
class _MermaidBlock extends StatefulWidget {
  const _MermaidBlock({required this.source, required this.dark});

  final String source;
  final bool dark;

  @override
  State<_MermaidBlock> createState() => _MermaidBlockState();
}

class _MermaidBlockState extends State<_MermaidBlock> {
  final GlobalKey _boundaryKey = GlobalKey();
  bool _exporting = false;

  Future<void> _download(BuildContext context) async {
    if (_exporting) return;
    setState(() => _exporting = true);
    final bool ok = await PngExporter.exportAndShare(
      boundaryKey: _boundaryKey,
      filename: 'flowchart',
    );
    if (!context.mounted) return;
    setState(() => _exporting = false);
    if (!ok) {
      UiToast.show(
        context,
        title: "Couldn't export diagram",
        message: 'Please try again.',
        intent: UiIntent.warning,
      );
    }
  }

  void _openFullscreen(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (_) =>
            _MermaidFullscreenView(source: widget.source, dark: widget.dark),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.uiColors;
    return _FencedBlockChrome(
      icon: Icons.account_tree_outlined,
      label: 'flowchart',
      bodyPadding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      actions: [
        _exporting
            ? const Padding(
                padding: EdgeInsets.all(8),
                child: SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              )
            : _ChromeIconButton(
                icon: Icons.download_outlined,
                tooltip: 'Download as PNG',
                onPressed: () => _download(context),
              ),
        _ChromeIconButton(
          icon: Icons.fullscreen,
          tooltip: 'View fullscreen',
          onPressed: () => _openFullscreen(context),
        ),
      ],
      body: GestureDetector(
        onTap: () => _openFullscreen(context),
        // The capture boundary wraps the *full-width* box (not the
        // diagram's natural-size render), so a downloaded PNG matches
        // exactly what is on screen.
        child: RepaintBoundary(
          key: _boundaryKey,
          child: Container(
            width: double.infinity,
            color: colors.surface,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 160),
                // Mermaid lays out at the diagram's own natural size, so a
                // narrow chart used to sit small and left-aligned.
                // `FittedBox` with `fitWidth` hands the diagram unbounded
                // constraints (natural size), then uniformly scales it to
                // span the card's width, preserving aspect ratio.
                child: SizedBox(
                  width: double.infinity,
                  child: FittedBox(
                    fit: BoxFit.fitWidth,
                    alignment: Alignment.topCenter,
                    child: FlowchartView(
                      source: widget.source,
                      palette: FlowchartPalette.themed(context),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Fullscreen pan/zoom viewer for a mermaid diagram, with its own PNG
/// download action.
class _MermaidFullscreenView extends StatefulWidget {
  const _MermaidFullscreenView({required this.source, required this.dark});

  final String source;
  final bool dark;

  @override
  State<_MermaidFullscreenView> createState() => _MermaidFullscreenViewState();
}

class _MermaidFullscreenViewState extends State<_MermaidFullscreenView> {
  final GlobalKey _boundaryKey = GlobalKey();
  final TransformationController _transform = TransformationController();
  bool _exporting = false;
  Size? _viewportSize;
  bool _didAutoFit = false;
  // Mermaid resolves its true rendered size a frame or two after first
  // build (it parses/lays out the diagram asynchronously), so an auto-fit
  // that trusts the very first measurement fits to a placeholder-sized box
  // and then visibly snaps to the real size right after — reading as
  // "zooms in then zooms back out". Tracking the last measured size and
  // only committing once two consecutive frames agree means we fit exactly
  // once, against the diagram's real, settled size.
  Size? _lastMeasured;
  // Once the person starts pinching/panning, auto-fit must never touch the
  // transform again — even if a late layout pass fires after that point —
  // or it fights their input by silently resetting what they just did.
  bool _userInteracted = false;

  @override
  void initState() {
    super.initState();
    // Give the diagram a frame to lay out at its natural (now unconstrained)
    // size, then zoom out just enough that the whole thing is visible instead
    // of opening at 100% with the bottom of a tall diagram off-screen.
    WidgetsBinding.instance.addPostFrameCallback((_) => _fitToScreen());
  }

  void _fitToScreen() {
    if (_didAutoFit || _userInteracted || !mounted) return;
    final RenderBox? box =
        _boundaryKey.currentContext?.findRenderObject() as RenderBox?;
    final Size? viewport = _viewportSize;
    if (box == null || viewport == null || !box.hasSize) return;
    final Size content = box.size;
    if (content.width <= 0 || content.height <= 0) return;

    // Not settled yet (or this is the first reading) — remember it and
    // wait for the next frame's measurement to confirm it before acting.
    if (_lastMeasured == null || _lastMeasured != content) {
      _lastMeasured = content;
      WidgetsBinding.instance.addPostFrameCallback((_) => _fitToScreen());
      return;
    }

    final double fitScale = math.min(
      viewport.width / content.width,
      viewport.height / content.height,
    );
    final double scale = fitScale.clamp(0.4, 1.0);
    final double dx = (viewport.width - content.width * scale) / 2;
    final double dy = (viewport.height - content.height * scale) / 2;
    _transform.value = Matrix4.translationValues(dx, dy, 0.0)
      ..multiply(Matrix4.diagonal3Values(scale, scale, 1.0));
    _didAutoFit = true;
  }

  void _handleInteractionStart(ScaleStartDetails _) {
    _userInteracted = true;
  }

  Future<void> _download() async {
    if (_exporting) return;
    setState(() => _exporting = true);
    final bool ok = await PngExporter.exportAndShare(
      boundaryKey: _boundaryKey,
      filename: 'flowchart',
    );
    if (!mounted) return;
    setState(() => _exporting = false);
    if (!ok) {
      UiToast.show(
        context,
        title: "Couldn't export diagram",
        message: 'Please try again.',
        intent: UiIntent.warning,
      );
    }
  }

  void _resetZoom() {
    // A deliberate tap on "Reset zoom" should actually refit — including
    // re-enabling auto-fit even after the person has already panned/pinched,
    // since that's exactly what they're now asking for.
    _didAutoFit = false;
    _userInteracted = false;
    _lastMeasured = null;
    _transform.value = Matrix4.identity();
    WidgetsBinding.instance.addPostFrameCallback((_) => _fitToScreen());
  }

  @override
  void dispose() {
    _transform.dispose();
    super.dispose();
  }

  Widget _buildViewer(Color bg) {
    return InteractiveViewer(
      // Without `constrained: false`, InteractiveViewer forces its child to
      // fit inside the viewport no matter what the child itself wants —
      // zooming still "works" but panning can never reveal anything past
      // the edge of that box, because the diagram was never actually laid
      // out larger than the screen in the first place. `constrained: false`
      // lets the child (here, sized to its natural content size via
      // UnconstrainedBox below) grow past the viewport so there's actually
      // something to pan to.
      constrained: false,
      minScale: 0.4,
      maxScale: 8,
      boundaryMargin: const EdgeInsets.all(120),
      transformationController: _transform,
      onInteractionStart: _handleInteractionStart,
      // `Center` hands its child *bounded* max constraints equal to the
      // viewport. Without `UnconstrainedBox`, `FlowchartView`'s responsive
      // sizing shrinks/clips itself to fit that box instead of laying out at
      // its natural content size — so a diagram taller than one screen never
      // renders what's past the fold, and panning has nothing extra to
      // reveal (this was the "stuck at half, can't scroll further" bug).
      // `UnconstrainedBox` ignores the incoming constraints so the diagram
      // lays out at full size, and `InteractiveViewer` can then pan/zoom
      // across the whole thing.
      child: Center(
        child: UnconstrainedBox(
          constrainedAxis: null,
          child: RepaintBoundary(
            key: _boundaryKey,
            child: Container(
              color: bg,
              padding: const EdgeInsets.all(24),
              child: FlowchartView(
                source: widget.source,
                palette: FlowchartPalette.themed(context),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final Color bg = widget.dark
        ? const Color(0xFF121212)
        : const Color(0xFFFAF9F6);
    final Color fg = widget.dark ? Colors.white : Colors.black87;
    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
              child: Row(
                children: [
                  IconButton(
                    icon: Icon(Icons.close, color: fg),
                    onPressed: () => Navigator.of(context).pop(),
                    tooltip: 'Close',
                  ),
                  Expanded(
                    child: Text(
                      'Flowchart',
                      style: TextStyle(
                        color: fg,
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.center_focus_strong_outlined, color: fg),
                    onPressed: _resetZoom,
                    tooltip: 'Reset zoom',
                  ),
                  _exporting
                      ? Padding(
                          padding: const EdgeInsets.all(12),
                          child: SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: fg,
                            ),
                          ),
                        )
                      : IconButton(
                          icon: Icon(Icons.download_outlined, color: fg),
                          onPressed: _download,
                          tooltip: 'Download as PNG',
                        ),
                ],
              ),
            ),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  _viewportSize = Size(
                    constraints.maxWidth,
                    constraints.maxHeight,
                  );
                  // Keep nudging _fitToScreen every build; it no-ops itself
                  // once it has committed a fit (or the person has taken
                  // over with a pinch/pan) — see _fitToScreen for the
                  // two-frame settle check that avoids fitting to a
                  // not-yet-final mermaid layout.
                  WidgetsBinding.instance.addPostFrameCallback(
                    (_) => _fitToScreen(),
                  );
                  return _buildViewer(bg);
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 10, top: 4),
              child: Text(
                'Pinch or scroll to zoom · drag to pan',
                style: TextStyle(
                  color: fg.withValues(alpha: 0.55),
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

extension<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
