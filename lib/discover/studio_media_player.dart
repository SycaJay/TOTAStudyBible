import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../app_colors.dart';
import '../user_messages.dart';

bool studioMediaIsVideo(String url) {
  final u = url.toLowerCase();
  return u.endsWith('.mp4') ||
      u.endsWith('.webm') ||
      u.endsWith('.m4v') ||
      u.contains('.mp4?');
}

bool studioMediaIsAudio(String url) => !studioMediaIsVideo(url);

class StudioInlinePlayer extends StatefulWidget {
  const StudioInlinePlayer({
    super.key,
    required this.title,
    required this.url,
    required this.onClose,
  });

  final String title;
  final String url;
  final VoidCallback onClose;

  @override
  State<StudioInlinePlayer> createState() => _StudioInlinePlayerState();
}

class _StudioInlinePlayerState extends State<StudioInlinePlayer> {
  VideoPlayerController? _controller;
  var _loading = true;
  String? _error;

  bool get _isVideo => studioMediaIsVideo(widget.url);

  @override
  void initState() {
    super.initState();
    _open(widget.url);
  }

  @override
  void didUpdateWidget(StudioInlinePlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url) {
      _disposeController();
      _open(widget.url);
    }
  }

  Future<void> _open(String url) async {
    setState(() {
      _loading = true;
      _error = null;
    });

    final uri = Uri.tryParse(url.trim());
    if (uri == null) {
      setState(() {
        _loading = false;
        _error = UserMessages.generic;
      });
      return;
    }

    try {
      final controller = VideoPlayerController.networkUrl(uri);
      _controller = controller;
      await controller.initialize();
      controller.addListener(() {
        if (mounted) setState(() {});
      });
      await controller.play();
      if (!mounted) return;
      setState(() => _loading = false);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = UserMessages.playMedia;
      });
    }
  }

  void _disposeController() {
    _controller?.dispose();
    _controller = null;
  }

  @override
  void dispose() {
    _disposeController();
    super.dispose();
  }

  Future<void> _togglePlayPause() async {
    final c = _controller;
    if (c == null || !c.value.isInitialized) return;
    if (c.value.isPlaying) {
      await c.pause();
    } else {
      await c.play();
    }
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final c = _controller;
    final playing = c?.value.isPlaying ?? false;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.cardBorder),
        boxShadow: [
          BoxShadow(
            color: AppColors.accentBlue.withValues(alpha: 0.08),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    widget.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Close player',
                  onPressed: widget.onClose,
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (_loading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 28),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_error != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Text(
                  _error!,
                  style: TextStyle(color: AppColors.inkMuted, height: 1.4),
                ),
              )
            else if (_isVideo && c != null && c.value.isInitialized)
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: AspectRatio(
                  aspectRatio: c.value.aspectRatio,
                  child: VideoPlayer(c),
                ),
              )
            else if (!_isVideo && c != null && c.value.isInitialized)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.headphones_rounded,
                      size: 40,
                      color: AppColors.accentBlue,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      playing ? 'Playing…' : 'Paused',
                      style: TextStyle(color: AppColors.inkMuted),
                    ),
                  ],
                ),
              ),
            if (!_loading && _error == null) ...[
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.center,
                child: IconButton.filled(
                  onPressed: _togglePlayPause,
                  icon: Icon(
                    playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
