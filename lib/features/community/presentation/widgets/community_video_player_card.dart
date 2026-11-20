import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:alphajournal/core/app-ui/app_ui.dart';
import 'package:url_launcher/url_launcher.dart';

import 'community_video_embed_stub.dart'
    if (dart.library.js_interop) 'community_video_embed_web.dart';
import 'community_video_parser.dart';

/// X/Twitter-style rounded 16:9 inline video card for Community posts.
///
/// Renders a crisp poster preview with provider pill & play overlay in the feed,
/// and swaps seamlessly into an inline embedded player (YouTube, Vimeo,
/// Dailymotion, Twitch, or HTML5 `<video>`) when tapped.
class CommunityVideoPlayerCard extends StatefulWidget {
  const CommunityVideoPlayerCard({
    super.key,
    required this.url,
    this.onRemove,
  });

  final String url;
  final VoidCallback? onRemove;

  @override
  State<CommunityVideoPlayerCard> createState() =>
      _CommunityVideoPlayerCardState();
}

class _CommunityVideoPlayerCardState extends State<CommunityVideoPlayerCard> {
  bool _playing = false;
  bool _hovered = false;

  Future<void> _openExternal(String url) async {
    final Uri? uri = Uri.tryParse(url);
    if (uri != null) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ParsedCommunityVideo? video = CommunityVideoParser.parse(widget.url);
    if (video == null) return const SizedBox.shrink();

    final UiTheme theme = context.ui;
    final BorderRadius radius = BorderRadius.circular(14);

    return ClipRRect(
      borderRadius: radius,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.black,
          borderRadius: radius,
          border: Border.all(color: theme.colors.border),
        ),
        child: AspectRatio(
          aspectRatio: 16 / 9,
          child: Stack(
            fit: StackFit.expand,
            children: <Widget>[
              if (_playing && kIsWeb) ...<Widget>[
                // Keep poster backdrop behind the iframe while it loads so
                // mobile browsers never flash a blank card.
                if (video.thumbnailUrl != null)
                  Image.network(
                    video.thumbnailUrl!,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => _fallbackBackdrop(theme, video),
                  )
                else
                  _fallbackBackdrop(theme, video),
                Positioned.fill(
                  child: CommunityVideoEmbed(
                    key: ValueKey<String>(video.embedUrl),
                    video: video,
                  ),
                ),
              ] else
                _buildPosterPreview(context, theme, video),

              if (widget.onRemove != null)
                Positioned(
                  top: 8,
                  right: 8,
                  child: Material(
                    color: Colors.black.withValues(alpha: 0.72),
                    shape: const CircleBorder(),
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: widget.onRemove,
                      child: const Padding(
                        padding: EdgeInsets.all(6),
                        child: Icon(
                          Icons.close_rounded,
                          size: 16,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPosterPreview(
    BuildContext context,
    UiTheme theme,
    ParsedCommunityVideo video,
  ) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: () {
          if (kIsWeb) {
            setState(() => _playing = true);
          } else {
            _openExternal(video.url);
          }
        },
        child: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            if (video.thumbnailUrl != null)
              Image.network(
                video.thumbnailUrl!,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => _fallbackBackdrop(theme, video),
              )
            else
              _fallbackBackdrop(theme, video),

            // Subtle dark scrim for crisp controls contrast
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: <Color>[
                    Colors.black.withValues(alpha: 0.08),
                    Colors.black.withValues(alpha: 0.18),
                    Colors.black.withValues(alpha: 0.56),
                  ],
                ),
              ),
            ),

            // Center Play Button
            Center(
              child: AnimatedScale(
                scale: _hovered ? 1.08 : 1.0,
                duration: const Duration(milliseconds: 160),
                curve: Curves.easeOutCubic,
                child: Container(
                  width: 58,
                  height: 58,
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.72),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.85),
                      width: 1.8,
                    ),
                    boxShadow: <BoxShadow>[
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.45),
                        blurRadius: 18,
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.play_arrow_rounded,
                    size: 34,
                    color: Colors.white,
                  ),
                ),
              ),
            ),

            // Bottom-left provider pill badge (X/Twitter style)
            Positioned(
              left: 10,
              bottom: 10,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.74),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Icon(video.providerIcon, size: 13, color: Colors.white),
                    const SizedBox(width: 5),
                    Text(
                      video.providerLabel,
                      style: context.uiText.caption.copyWith(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Bottom-right open external link button
            Positioned(
              right: 10,
              bottom: 10,
              child: Material(
                color: Colors.black.withValues(alpha: 0.72),
                borderRadius: BorderRadius.circular(8),
                child: InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: () => _openExternal(video.url),
                  child: const Padding(
                    padding: EdgeInsets.all(6),
                    child: Icon(
                      Icons.open_in_new_rounded,
                      size: 15,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _fallbackBackdrop(UiTheme theme, ParsedCommunityVideo video) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            theme.colors.surfaceMuted,
            const Color(0xFF0E1014),
          ],
        ),
      ),
      alignment: Alignment.center,
      child: Icon(
        video.providerIcon,
        size: 56,
        color: Colors.white.withValues(alpha: 0.16),
      ),
    );
  }
}

/// Dialog allowing users to attach a YouTube, Vimeo, Dailymotion, Twitch, or
/// direct MP4/WebM video URL with live validation and poster preview.
Future<String?> showCommunityVideoAttachDialog(
  BuildContext context, {
  String? initialUrl,
}) async {
  final TextEditingController ctrl = TextEditingController(
    text: initialUrl ?? '',
  );
  final String? picked = await UiDialog.show<String>(
    context,
    maxWidth: 520,
    child: StatefulBuilder(
      builder: (BuildContext ctx, StateSetter setDialogState) {
        final UiTheme theme = ctx.ui;
        final String raw = ctrl.text.trim();
        final ParsedCommunityVideo? parsed = CommunityVideoParser.parse(raw);
        final bool hasError = raw.isNotEmpty && parsed == null;

        return UiDialog(
          title: 'Attach Video',
          description:
              'Paste a YouTube, Vimeo, Dailymotion, Twitch, or direct MP4/WebM video link.',
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              TextField(
                controller: ctrl,
                autofocus: true,
                onChanged: (_) => setDialogState(() {}),
                style: ctx.uiText.body,
                decoration: InputDecoration(
                  hintText: 'https://www.youtube.com/watch?v=…',
                  prefixIcon: Icon(
                    Icons.smart_display_outlined,
                    size: 18,
                    color: theme.colors.foregroundMuted,
                  ),
                  isDense: true,
                  filled: true,
                  fillColor: theme.colors.surfaceMuted.withValues(alpha: 0.45),
                  errorText: hasError
                      ? 'Unsupported link. Use YouTube, Vimeo, Dailymotion, Twitch, or .mp4/.webm.'
                      : null,
                  border: OutlineInputBorder(
                    borderRadius: ctx.radius(theme.radii.md),
                    borderSide: BorderSide(color: theme.colors.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: ctx.radius(theme.radii.md),
                    borderSide: BorderSide(color: theme.colors.border),
                  ),
                ),
              ),
              if (parsed != null) ...<Widget>[
                SizedBox(height: ctx.sp(theme.spacing.sm)),
                CommunityVideoPlayerCard(url: parsed.url),
              ],
            ],
          ),
          actions: <Widget>[
            if (initialUrl != null && initialUrl.isNotEmpty)
              UiButton(
                label: 'Remove Video',
                variant: UiVariant.ghost,
                intent: UiIntent.danger,
                onPressed: () => Navigator.of(ctx).pop(''),
              ),
            UiButton(
              label: 'Cancel',
              variant: UiVariant.outline,
              onPressed: () => Navigator.of(ctx).pop(),
            ),
            UiButton(
              label: 'Attach Video',
              onPressed: parsed == null
                  ? null
                  : () => Navigator.of(ctx).pop(parsed.url),
            ),
          ],
        );
      },
    ),
  );
  ctrl.dispose();
  return picked;
}
