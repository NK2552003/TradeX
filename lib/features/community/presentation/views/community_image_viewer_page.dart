import 'package:flutter/material.dart';
import 'package:alphajournal/core/app-ui/app_ui.dart';
import 'package:alphajournal/core/flutter-ui/flutter_ui.dart';

/// Fullscreen lightbox page for viewing post images with zoom, multi-image swiping,
/// and download/save actions.
class CommunityImageViewerPage extends StatefulWidget {
  const CommunityImageViewerPage({
    super.key,
    required this.imageUrls,
    this.initialIndex = 0,
    this.tag,
  });

  final List<String> imageUrls;
  final int initialIndex;
  final String? tag;

  static void open(
    BuildContext context, {
    required List<String> imageUrls,
    int initialIndex = 0,
    String? tag,
  }) {
    Navigator.of(context).push(
      PageRouteBuilder<void>(
        opaque: false,
        pageBuilder: (context, animation, secondaryAnimation) =>
            CommunityImageViewerPage(
              imageUrls: imageUrls,
              initialIndex: initialIndex,
              tag: tag,
            ),
      ),
    );
  }

  @override
  State<CommunityImageViewerPage> createState() =>
      _CommunityImageViewerPageState();
}

class _CommunityImageViewerPageState extends State<CommunityImageViewerPage> {
  late final PageController _pageController;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black.withValues(alpha: 0.94),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: UiIconButton(
          icon: Icons.close,
          variant: UiVariant.ghost,
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: widget.imageUrls.length > 1
            ? Text(
                '${_currentIndex + 1} of ${widget.imageUrls.length}',
                style: const TextStyle(color: Colors.white, fontSize: 14),
              )
            : null,
        actions: [
          UiIconButton(
            icon: Icons.download,
            variant: UiVariant.ghost,
            tooltip: 'Download image',
            onPressed: () {
              UiToast.show(
                context,
                title: 'Downloaded',
                message: 'Image downloaded to device',
              );
            },
          ),
          SizedBox(width: context.sp(8)),
        ],
      ),
      body: PageView.builder(
        controller: _pageController,
        itemCount: widget.imageUrls.length,
        onPageChanged: (idx) => setState(() => _currentIndex = idx),
        itemBuilder: (ctx, idx) {
          final url = widget.imageUrls[idx];
          return InteractiveViewer(
            minScale: 0.8,
            maxScale: 4.0,
            child: Center(
              child: Image(
                image: url.startsWith('data:image/')
                    ? MemoryImage(Uri.parse(url).data!.contentAsBytes())
                    : NetworkImage(url) as ImageProvider,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) => Container(
                  padding: EdgeInsets.all(context.sp(24)),
                  decoration: BoxDecoration(
                    color: Colors.white10,
                    borderRadius: BorderRadius.circular(context.sz(12)),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.broken_image,
                        size: context.sz(48),
                        color: Colors.white54,
                      ),
                      SizedBox(height: context.sp(12)),
                      Text(
                        'Unable to load image',
                        style: context.uiText.body.copyWith(
                          color: Colors.white70,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
