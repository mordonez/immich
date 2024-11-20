import 'package:chewie/chewie.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:immich_mobile/providers/app_settings.provider.dart';
import 'package:immich_mobile/services/app_settings.service.dart';
import 'package:immich_mobile/utils/hooks/chewiew_controller_hook.dart';
import 'package:immich_mobile/widgets/asset_viewer/custom_video_player_controls.dart';
import 'package:video_player/video_player.dart';

class VideoPlayerViewer extends HookConsumerWidget {
  final VideoPlayerController controller;
  final Duration hideControlsTimer;
  final bool showControls;
  final bool autoPlay;

  const VideoPlayerViewer({
    super.key,
    required this.controller,
    required this.showControls,
    this.hideControlsTimer = const Duration(seconds: 5),
    this.autoPlay = true,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loopVideo = ref.watch(
      appSettingsServiceProvider.select(
        (settings) => settings.getSetting<bool>(AppSettingsEnum.loopVideo),
      ),
    );

    final chewie = useChewieController(
      controller: controller,
      controlsSafeAreaMinimum: const EdgeInsets.only(bottom: 100),
      customControls:
          CustomVideoPlayerControls(hideTimerDuration: hideControlsTimer),
      showControls: showControls,
      hideControlsTimer: hideControlsTimer,
      loopVideo: loopVideo,
      autoPlay: autoPlay,
    );

    return Chewie(controller: chewie);
  }
}
