import 'dart:ui_web' as ui_web;

import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;

import 'community_video_parser.dart';

int _videoViewSeq = 0;

/// Coordinates CSS `pointer-events` on active embedded video elements so
/// Flutter overlays (e.g. reaction hover trays, menus, dialogs) rendered above
/// a playing video receive hover & click events cleanly without being stolen
/// by the underlying DOM `<iframe>` / `<video>`.
class CommunityVideoPointerGuard {
  static final Set<web.HTMLElement> _activeElements = <web.HTMLElement>{};
  static int _overlayLocks = 0;

  static void register(web.HTMLElement element) {
    _activeElements.add(element);
    element.style.pointerEvents = _overlayLocks > 0 ? 'none' : 'auto';
  }

  static void unregister(web.HTMLElement element) {
    _activeElements.remove(element);
  }

  static void acquire() {
    _overlayLocks++;
    for (final web.HTMLElement el in _activeElements) {
      el.style.pointerEvents = 'none';
    }
  }

  static void release() {
    if (_overlayLocks > 0) _overlayLocks--;
    if (_overlayLocks == 0) {
      for (final web.HTMLElement el in _activeElements) {
        el.style.pointerEvents = 'auto';
      }
    }
  }
}

/// Flutter Web inline embedded video player supporting YouTube, Vimeo,
/// Dailymotion, Twitch iframes and native HTML5 `<video>` streams.
class CommunityVideoEmbed extends StatefulWidget {
  const CommunityVideoEmbed({super.key, required this.video});

  final ParsedCommunityVideo video;

  @override
  State<CommunityVideoEmbed> createState() => _CommunityVideoEmbedState();
}

class _CommunityVideoEmbedState extends State<CommunityVideoEmbed> {
  late final String _viewType;
  web.HTMLElement? _element;

  @override
  void initState() {
    super.initState();
    _viewType = 'alphajournal-community-video-${++_videoViewSeq}';
    final ParsedCommunityVideo video = widget.video;
    final String host = web.window.location.hostname;
    final ParsedCommunityVideo resolved =
        CommunityVideoParser.parse(video.url, webHost: host) ?? video;

    ui_web.platformViewRegistry.registerViewFactory(_viewType, (int _) {
      if (resolved.isDirectVideo) {
        final web.HTMLVideoElement el = web.HTMLVideoElement()
          ..src = resolved.embedUrl
          ..controls = true
          ..autoplay = true
          ..playsInline = true
          ..preload = 'auto'
          ..style.position = 'absolute'
          ..style.inset = '0'
          ..style.display = 'block'
          ..style.width = '100%'
          ..style.height = '100%'
          ..style.border = 'none'
          ..style.backgroundColor = '#000000'
          ..style.objectFit = 'contain';
        el.setAttribute('playsinline', '');
        el.setAttribute('webkit-playsinline', '');
        _element = el;
        CommunityVideoPointerGuard.register(el);
        return el;
      }

      final web.HTMLIFrameElement iframe = web.HTMLIFrameElement()
        ..src = resolved.embedUrl
        ..referrerPolicy = 'strict-origin-when-cross-origin'
        ..allow =
            'accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture; web-share; fullscreen'
        ..allowFullscreen = true
        ..style.position = 'absolute'
        ..style.inset = '0'
        ..style.display = 'block'
        ..style.width = '100%'
        ..style.height = '100%'
        ..style.border = 'none'
        ..style.backgroundColor = '#000000';
      iframe.setAttribute('frameborder', '0');
      iframe.setAttribute('allowfullscreen', 'true');
      iframe.setAttribute('webkitallowfullscreen', 'true');
      iframe.setAttribute('mozallowfullscreen', 'true');
      _element = iframe;
      CommunityVideoPointerGuard.register(iframe);
      return iframe;
    });
  }

  @override
  void dispose() {
    if (_element != null) {
      CommunityVideoPointerGuard.unregister(_element!);
      _element = null;
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return HtmlElementView(viewType: _viewType);
  }
}
