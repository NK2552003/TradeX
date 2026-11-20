import 'package:flutter/material.dart';

enum CommunityVideoProvider { youtube, vimeo, dailymotion, twitch, direct }

@immutable
class ParsedCommunityVideo {
  const ParsedCommunityVideo({
    required this.url,
    required this.provider,
    required this.embedUrl,
    this.videoId,
    this.thumbnailUrl,
  });

  final String url;
  final CommunityVideoProvider provider;
  final String embedUrl;
  final String? videoId;
  final String? thumbnailUrl;

  bool get isDirectVideo => provider == CommunityVideoProvider.direct;

  String get providerLabel => switch (provider) {
    CommunityVideoProvider.youtube => 'YouTube',
    CommunityVideoProvider.vimeo => 'Vimeo',
    CommunityVideoProvider.dailymotion => 'Dailymotion',
    CommunityVideoProvider.twitch => 'Twitch',
    CommunityVideoProvider.direct => 'Video',
  };

  IconData get providerIcon => switch (provider) {
    CommunityVideoProvider.youtube => Icons.play_circle_fill_rounded,
    CommunityVideoProvider.vimeo => Icons.ondemand_video_rounded,
    CommunityVideoProvider.dailymotion => Icons.video_library_rounded,
    CommunityVideoProvider.twitch => Icons.live_tv_rounded,
    CommunityVideoProvider.direct => Icons.movie_outlined,
  };
}

class CommunityVideoParser {
  static final RegExp _urlInTextPattern = RegExp(
    r'https?://[^\s<>"]+',
    caseSensitive: false,
  );

  static ParsedCommunityVideo? parse(String rawUrl, {String? webHost}) {
    final String trimmed = rawUrl.trim();
    if (trimmed.isEmpty) return null;
    final Uri? uri = Uri.tryParse(trimmed);
    if (uri == null || !uri.hasScheme || (uri.scheme != 'http' && uri.scheme != 'https')) {
      return null;
    }

    final String host = uri.host.toLowerCase().replaceFirst(RegExp(r'^www\.'), '');
    final List<String> segs = uri.pathSegments.where((s) => s.isNotEmpty).toList();

    // 1. YouTube (watch, youtu.be, shorts, embed, live)
    String? ytId;
    if (host == 'youtu.be' && segs.isNotEmpty) {
      ytId = segs.first;
    } else if (host == 'youtube.com' ||
        host == 'm.youtube.com' ||
        host == 'music.youtube.com' ||
        host == 'youtube-nocookie.com') {
      if (uri.queryParameters['v'] != null &&
          uri.queryParameters['v']!.isNotEmpty) {
        ytId = uri.queryParameters['v'];
      } else if (segs.length >= 2 &&
          const {'embed', 'shorts', 'live', 'v'}.contains(segs.first)) {
        ytId = segs[1];
      }
    }
    if (ytId != null && RegExp(r'^[A-Za-z0-9_\-]{6,20}$').hasMatch(ytId)) {
      return ParsedCommunityVideo(
        url: trimmed,
        provider: CommunityVideoProvider.youtube,
        videoId: ytId,
        embedUrl:
            'https://www.youtube-nocookie.com/embed/$ytId?autoplay=1&rel=0&modestbranding=1&playsinline=1',
        thumbnailUrl: 'https://img.youtube.com/vi/$ytId/hqdefault.jpg',
      );
    }

    // 2. Vimeo
    if (host == 'vimeo.com' || host == 'player.vimeo.com') {
      for (final String seg in segs.reversed) {
        if (RegExp(r'^\d{6,14}$').hasMatch(seg)) {
          return ParsedCommunityVideo(
            url: trimmed,
            provider: CommunityVideoProvider.vimeo,
            videoId: seg,
            embedUrl: 'https://player.vimeo.com/video/$seg?autoplay=1&dnt=1',
          );
        }
      }
    }

    // 3. Dailymotion
    if (host == 'dailymotion.com' || host == 'dai.ly') {
      String? dmId;
      if (host == 'dai.ly' && segs.isNotEmpty) {
        dmId = segs.first;
      } else if (segs.length >= 2 && segs.first == 'video') {
        dmId = segs[1].split('_').first;
      } else if (segs.length >= 3 && segs[0] == 'embed' && segs[1] == 'video') {
        dmId = segs[2];
      }
      if (dmId != null && RegExp(r'^[A-Za-z0-9]{4,20}$').hasMatch(dmId)) {
        return ParsedCommunityVideo(
          url: trimmed,
          provider: CommunityVideoProvider.dailymotion,
          videoId: dmId,
          embedUrl:
              'https://www.dailymotion.com/embed/video/$dmId?autoplay=1',
          thumbnailUrl: 'https://www.dailymotion.com/thumbnail/video/$dmId',
        );
      }
    }

    // 4. Twitch (VODs & clips)
    if (host == 'twitch.tv' || host == 'clips.twitch.tv') {
      final String parent = (webHost != null && webHost.isNotEmpty)
          ? webHost
          : 'localhost';
      if (host == 'clips.twitch.tv' && segs.isNotEmpty) {
        final String clip = segs.first;
        return ParsedCommunityVideo(
          url: trimmed,
          provider: CommunityVideoProvider.twitch,
          videoId: clip,
          embedUrl:
              'https://clips.twitch.tv/embed?clip=$clip&parent=$parent&autoplay=true',
        );
      }
      if (segs.length >= 2 && segs.first == 'videos') {
        final String vod = segs[1];
        return ParsedCommunityVideo(
          url: trimmed,
          provider: CommunityVideoProvider.twitch,
          videoId: vod,
          embedUrl:
              'https://player.twitch.tv/?video=$vod&parent=$parent&autoplay=true',
        );
      }
    }

    // 5. Direct video file URL (.mp4, .webm, .mov, .m4v, .ogg)
    final String lowerPath = uri.path.toLowerCase();
    if (lowerPath.endsWith('.mp4') ||
        lowerPath.endsWith('.webm') ||
        lowerPath.endsWith('.mov') ||
        lowerPath.endsWith('.m4v') ||
        lowerPath.endsWith('.ogg')) {
      return ParsedCommunityVideo(
        url: trimmed,
        provider: CommunityVideoProvider.direct,
        embedUrl: trimmed,
      );
    }

    return null;
  }

  /// Extracts the first supported video URL found anywhere in [text].
  static ParsedCommunityVideo? extractFromText(String text, {String? webHost}) {
    for (final Match m in _urlInTextPattern.allMatches(text)) {
      final String candidate = (m.group(0) ?? '').replaceAll(
        RegExp(r'[.,)!?\]]+$'),
        '',
      );
      final parsed = parse(candidate, webHost: webHost);
      if (parsed != null) return parsed;
    }
    return null;
  }
}
