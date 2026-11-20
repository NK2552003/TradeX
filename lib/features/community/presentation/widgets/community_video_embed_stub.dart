import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'community_video_parser.dart';

/// No-op pointer guard on non-web platforms.
class CommunityVideoPointerGuard {
  static void acquire() {}
  static void release() {}
}

/// Native/non-web fallback embed that launches the video in the system
/// in-app browser/player when tapped.
class CommunityVideoEmbed extends StatelessWidget {
  const CommunityVideoEmbed({super.key, required this.video});

  final ParsedCommunityVideo video;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black,
      alignment: Alignment.center,
      child: TextButton.icon(
        onPressed: () async {
          final uri = Uri.tryParse(video.url);
          if (uri != null) {
            await launchUrl(uri, mode: LaunchMode.externalApplication);
          }
        },
        icon: const Icon(Icons.open_in_new_rounded, color: Colors.white),
        label: Text(
          'Open in ${video.providerLabel}',
          style: const TextStyle(color: Colors.white),
        ),
      ),
    );
  }
}
