// lib/core/widgets/fullscreen_photo_viewer.dart

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';
import '../theme/app_theme.dart';

class FullscreenPhotoViewer extends StatefulWidget {
  final List<String> imageUrls;
  final List<String?> captions;
  final int initialIndex;

  const FullscreenPhotoViewer({
    super.key,
    required this.imageUrls,
    this.captions = const [],
    this.initialIndex = 0,
  });

  static void open(
    BuildContext context, {
    required List<String> imageUrls,
    List<String?> captions = const [],
    int initialIndex = 0,
  }) {
    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        barrierColor: Colors.black87,
        pageBuilder: (context, animation, secondaryAnimation) {
          return FullscreenPhotoViewer(
            imageUrls: imageUrls,
            captions: captions,
            initialIndex: initialIndex,
          );
        },
        transitionsBuilder:
            (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration:
            const Duration(milliseconds: 250),
        reverseTransitionDuration:
            const Duration(milliseconds: 200),
      ),
    );
  }

  @override
  State<FullscreenPhotoViewer> createState() =>
      _FullscreenPhotoViewerState();
}

class _FullscreenPhotoViewerState
    extends State<FullscreenPhotoViewer> {
  late int _currentIndex;
  late PageController _pageController;
  bool _showOverlay = true;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController =
        PageController(initialPage: widget.initialIndex);
    SystemChrome.setEnabledSystemUIMode(
        SystemUiMode.immersiveSticky);
  }

  @override
  void dispose() {
    _pageController.dispose();
    SystemChrome.setEnabledSystemUIMode(
        SystemUiMode.edgeToEdge);
    super.dispose();
  }

  String? get _currentCaption {
    if (_currentIndex < widget.captions.length) {
      return widget.captions[_currentIndex];
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final caption = _currentCaption;
    final hasMultiple = widget.imageUrls.length > 1;

    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTap: () =>
            setState(() => _showOverlay = !_showOverlay),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // ── Zoomable gallery ──────────────────────────────
            PhotoViewGallery.builder(
              itemCount: widget.imageUrls.length,
              pageController: _pageController,
              scrollPhysics:
                  const BouncingScrollPhysics(),
              backgroundDecoration: const BoxDecoration(
                  color: Colors.black),
              onPageChanged: (index) =>
                  setState(() => _currentIndex = index),
              builder: (context, index) {
                return PhotoViewGalleryPageOptions(
                  imageProvider: CachedNetworkImageProvider(
                      widget.imageUrls[index]),
                  initialScale:
                      PhotoViewComputedScale.contained,
                  minScale:
                      PhotoViewComputedScale.contained *
                          0.8,
                  maxScale:
                      PhotoViewComputedScale.covered * 3,
                  errorBuilder:
                      (context, error, stackTrace) {
                    return const Center(
                      child: Icon(Icons.broken_image,
                          color: AppTheme.textSecondary,
                          size: 64),
                    );
                  },
                );
              },
              loadingBuilder: (context, event) {
                return Center(
                  child: SizedBox(
                    width: 36,
                    height: 36,
                    child: CircularProgressIndicator(
                      color: AppTheme.accentGreen,
                      strokeWidth: 2.5,
                      value: event == null
                          ? null
                          : event.cumulativeBytesLoaded /
                              (event.expectedTotalBytes ??
                                  1),
                    ),
                  ),
                );
              },
            ),

            // ── Close button ──────────────────────────────────
            if (_showOverlay)
              Positioned(
                top: MediaQuery.of(context).padding.top +
                    8,
                right: 12,
                child: GestureDetector(
                  onTap: () => Navigator.of(context).pop(),
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius:
                          BorderRadius.circular(20),
                    ),
                    child: const Icon(Icons.close,
                        color: Colors.white, size: 22),
                  ),
                ),
              ),

            // ── Page counter ──────────────────────────────────
            if (_showOverlay && hasMultiple)
              Positioned(
                top: MediaQuery.of(context).padding.top +
                    14,
                left: 0,
                right: 0,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius:
                          BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${_currentIndex + 1} / ${widget.imageUrls.length}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),

            // ── Caption ───────────────────────────────────────
            if (_showOverlay &&
                caption != null &&
                caption.isNotEmpty)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Container(
                  padding: EdgeInsets.fromLTRB(
                    20,
                    28,
                    20,
                    MediaQuery.of(context).padding.bottom +
                        16,
                  ),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Color(0xCC000000)
                      ],
                    ),
                  ),
                  child: Text(
                    caption,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      height: 1.35,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}