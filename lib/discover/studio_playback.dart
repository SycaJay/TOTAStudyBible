import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../user_messages.dart';

/// Global sermon player (survives tab changes).
class StudioPlayback extends ChangeNotifier {
  String? title;
  String? url;
  VideoPlayerController? controller;
  var loading = false;
  String? error;

  bool get isActive => url != null && url!.isNotEmpty;

  Future<void> start(String mediaUrl, String mediaTitle) async {
    if (mediaUrl == url && controller != null) {
      await togglePlayPause();
      return;
    }
    await _disposeController();
    url = mediaUrl;
    title = mediaTitle;
    loading = true;
    error = null;
    notifyListeners();

    final uri = Uri.tryParse(mediaUrl.trim());
    if (uri == null) {
      loading = false;
      error = UserMessages.generic;
      notifyListeners();
      return;
    }

    try {
      final c = VideoPlayerController.networkUrl(uri);
      controller = c;
      await c.initialize();
      c.addListener(_onTick);
      await c.play();
      loading = false;
      error = null;
    } catch (_) {
      loading = false;
      error = UserMessages.playMedia;
    }
    notifyListeners();
  }

  void _onTick() => notifyListeners();

  Future<void> close() async {
    await _disposeController();
    url = null;
    title = null;
    loading = false;
    error = null;
    notifyListeners();
  }

  Future<void> togglePlayPause() async {
    final c = controller;
    if (c == null || !c.value.isInitialized) return;
    if (c.value.isPlaying) {
      await c.pause();
    } else {
      await c.play();
    }
    notifyListeners();
  }

  Future<void> seekTo(Duration position) async {
    final c = controller;
    if (c == null || !c.value.isInitialized) return;
    await c.seekTo(position);
    notifyListeners();
  }

  Future<void> _disposeController() async {
    final c = controller;
    controller = null;
    if (c != null) {
      c.removeListener(_onTick);
      await c.dispose();
    }
  }

  @override
  void dispose() {
    _disposeController();
    super.dispose();
  }
}

class StudioPlaybackScope extends InheritedNotifier<StudioPlayback> {
  const StudioPlaybackScope({
    super.key,
    required StudioPlayback playback,
    required super.child,
  }) : super(notifier: playback);

  static StudioPlayback of(BuildContext context) {
    final scope =
        context.dependOnInheritedWidgetOfExactType<StudioPlaybackScope>();
    assert(scope != null, 'StudioPlaybackScope not found');
    return scope!.notifier!;
  }
}

String formatStudioElapsed(Duration d) {
  final h = d.inHours;
  final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
  final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
  if (h > 0) return '$h:$m:$s';
  return '$m:$s';
}
