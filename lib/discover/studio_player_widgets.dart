import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../app_colors.dart';
import 'studio_media_player.dart';
import 'studio_playback.dart';

class StudioPlayerControls extends StatelessWidget {
  const StudioPlayerControls({
    super.key,
    required this.playback,
    this.dense = false,
  });

  final StudioPlayback playback;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: playback,
      builder: (context, _) {
        final c = playback.controller;
        if (playback.loading) {
          return Padding(
            padding: EdgeInsets.symmetric(vertical: dense ? 4 : 12),
            child: const LinearProgressIndicator(),
          );
        }
        if (playback.error != null) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              playback.error!,
              style: TextStyle(
                fontSize: dense ? 12 : 14,
                color: AppColors.inkMuted,
              ),
            ),
          );
        }
        if (c == null || !c.value.isInitialized) {
          return const SizedBox.shrink();
        }

        final position = c.value.position;
        final duration = c.value.duration;
        final maxMs = duration.inMilliseconds;
        final sliderMax = maxMs > 0 ? maxMs.toDouble() : 1.0;
        final sliderValue = maxMs > 0
            ? position.inMilliseconds.clamp(0, maxMs).toDouble()
            : 0.0;
        final playing = c.value.isPlaying;

        return Row(
          children: [
            IconButton(
              visualDensity: dense ? VisualDensity.compact : VisualDensity.standard,
              padding: dense ? EdgeInsets.zero : null,
              constraints: dense
                  ? const BoxConstraints(minWidth: 36, minHeight: 36)
                  : null,
              onPressed: playback.togglePlayPause,
              icon: Icon(
                playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                color: AppColors.accentBlue,
                size: dense ? 28 : 32,
              ),
            ),
            Expanded(
              child: SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  trackHeight: dense ? 2.5 : 3,
                  thumbShape: RoundSliderThumbShape(
                    enabledThumbRadius: dense ? 5 : 6,
                  ),
                  overlayShape: SliderComponentShape.noOverlay,
                ),
                child: Slider(
                  value: sliderValue,
                  max: sliderMax,
                  onChanged: maxMs > 0
                      ? (v) => playback.seekTo(
                          Duration(milliseconds: v.round()),
                        )
                      : null,
                ),
              ),
            ),
            SizedBox(
              width: dense ? 52 : 56,
              child: Text(
                formatStudioElapsed(position),
                textAlign: TextAlign.end,
                style: TextStyle(
                  fontSize: dense ? 12 : 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.inkSoft,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class StudioInlinePlayer extends StatelessWidget {
  const StudioInlinePlayer({
    super.key,
    required this.playback,
    required this.onClose,
  });

  final StudioPlayback playback;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: playback,
      builder: (context, _) {
        final title = playback.title ?? '';
        final c = playback.controller;
        final isVideo =
            playback.url != null && studioMediaIsVideo(playback.url!);

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
                        title,
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
                      onPressed: onClose,
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
                if (isVideo &&
                    !playback.loading &&
                    c != null &&
                    c.value.isInitialized) ...[
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: AspectRatio(
                      aspectRatio: c.value.aspectRatio,
                      child: VideoPlayer(c),
                    ),
                  ),
                ],
                if (!isVideo &&
                    !playback.loading &&
                    playback.error == null &&
                    c != null &&
                    c.value.isInitialized)
                  const Padding(
                    padding: EdgeInsets.only(top: 4, bottom: 4),
                    child: Icon(
                      Icons.headphones_rounded,
                      size: 36,
                      color: AppColors.accentBlue,
                    ),
                  ),
                StudioPlayerControls(playback: playback),
              ],
            ),
          ),
        );
      },
    );
  }
}

class StudioMiniPlayerBar extends StatelessWidget {
  const StudioMiniPlayerBar({
    super.key,
    required this.playback,
    required this.onOpenDiscover,
  });

  final StudioPlayback playback;
  final VoidCallback onOpenDiscover;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: playback,
      builder: (context, _) {
        if (!playback.isActive) return const SizedBox.shrink();

        return Material(
          color: Colors.white,
          elevation: 8,
          child: InkWell(
            onTap: onOpenDiscover,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.headphones_rounded,
                        color: AppColors.accentBlue,
                        size: 22,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          playback.title ?? 'Sermon',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Close',
                        visualDensity: VisualDensity.compact,
                        onPressed: playback.close,
                        icon: const Icon(Icons.close_rounded, size: 20),
                      ),
                    ],
                  ),
                  StudioPlayerControls(playback: playback, dense: true),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
