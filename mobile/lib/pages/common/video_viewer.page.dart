import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:immich_mobile/entities/asset.entity.dart';
import 'package:immich_mobile/providers/asset_viewer/current_asset.provider.dart';
import 'package:immich_mobile/providers/asset_viewer/is_motion_video_playing.provider.dart';
import 'package:immich_mobile/providers/asset_viewer/video_player_controller_provider.dart';
import 'package:immich_mobile/providers/asset_viewer/video_player_controls_provider.dart';
import 'package:immich_mobile/providers/asset_viewer/video_player_value_provider.dart';
import 'package:immich_mobile/widgets/asset_viewer/custom_video_player_controls.dart';
import 'package:immich_mobile/widgets/asset_viewer/video_player.dart';
import 'package:logging/logging.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

/// Note: this only exists for remote video playback on Android.
/// TODO: Remove this when seeking remote videos on Android in the native video player is smooth.
class VideoViewerPage extends HookConsumerWidget {
  final Asset asset;
  final Widget image;
  final bool showControls;

  const VideoViewerPage({
    super.key,
    required this.asset,
    required this.image,
    this.showControls = true,
  });

  @override
  build(BuildContext context, WidgetRef ref) {
    final controller =
        ref.watch(videoPlayerControllerProvider(asset: asset)).value;
    // The last volume of the video used when mute is toggled
    final lastVolume = useState(0.5);

    // When a video is opened through the timeline, `isCurrent` will immediately be true.
    // When swiping from video A to video B, `isCurrent` will initially be true for video A and false for video B.
    // If the swipe is completed, `isCurrent` will be true for video B after a delay.
    // If the swipe is canceled, `currentAsset` will not have changed and video A will continue to play.
    final currentAsset = useState(ref.read(currentAssetProvider));
    final isCurrent = currentAsset.value == asset;
    final showMotionVideo = useState(false);

    final log = Logger('VideoViewerPage');

    // When the volume changes, set the volume
    ref.listen(videoPlayerControlsProvider.select((value) => value.mute),
        (_, mute) {
      if (mute) {
        controller?.setVolume(0.0);
      } else {
        controller?.setVolume(lastVolume.value);
      }
    });

    // When the position changes, seek to the position
    ref.listen(videoPlayerControlsProvider.select((value) => value.position),
        (_, position) {
      if (controller == null) {
        // No seeeking if there is no video
        return;
      }

      // Find the position to seek to
      controller.seekTo(Duration(seconds: position ~/ 1));
    });

    // When the custom video controls pause or play
    ref.listen(videoPlayerControlsProvider.select((value) => value.pause),
        (lastPause, pause) async {
      if (controller == null || asset.isMotionPhoto) {
        return;
      }

      if (pause) {
        await controller.pause();
      } else {
        await controller.play();
      }
    });

    ref.listen(isPlayingMotionVideoProvider, (_, value) async {
      if (!asset.isMotionPhoto || controller == null || !context.mounted) {
        return;
      }

      showMotionVideo.value = value;
      try {
        if (value) {
          await controller.seekTo(Duration.zero);
          await controller.play();
        } else {
          await controller.pause();
        }
      } catch (error) {
        log.severe('Error toggling motion video: $error');
      }
    });

    // Updates the [videoPlaybackValueProvider] with the current
    // position and duration of the video from the Chewie [controller]
    // Also sets the error if there is an error in the playback
    void updateVideoPlayback() {
      final videoPlayback = VideoPlaybackValue.fromController(controller);
      ref.read(videoPlaybackValueProvider.notifier).value = videoPlayback;
      final state = videoPlayback.state;

      // Enable the WakeLock while the video is playing
      if (state == VideoPlaybackState.playing) {
        // Sync with the controls playing
        WakelockPlus.enable();
      } else {
        // Sync with the controls pause
        WakelockPlus.disable();
      }
    }

    ref.listen(currentAssetProvider, (_, value) {
      if (controller != null && value != asset) {
        controller.removeListener(updateVideoPlayback);
      }

      currentAsset.value = value;
    });

    // Adds and removes the listener to the video player
    useEffect(
      () {
        Future.microtask(
          () => ref.read(videoPlayerControlsProvider.notifier).reset(),
        );
        // Guard no controller
        if (controller == null) {
          return null;
        }

        Future.microtask(() => controller.addListener(updateVideoPlayback));
        return () {
          ref.read(videoPlayerControlsProvider.notifier).reset();
          ref.read(videoPlaybackValueProvider.notifier).reset();
          WakelockPlus.disable();
          // Removes listener when we dispose
          controller.removeListener(updateVideoPlayback);
          controller.pause();
        };
      },
      [controller],
    );

    return Stack(
      children: [
        Center(key: ValueKey(asset.id), child: image),
        if (controller != null && isCurrent)
          Visibility.maintain(
            key: ValueKey(asset),
            visible: asset.isVideo || showMotionVideo.value,
            child: Center(
              key: ValueKey(asset),
              child: VideoPlayerViewer(
                controller: controller,
                showControls: showControls,
                autoPlay: asset.isVideo,
              ),
            ),
          ),
        if (showControls) const Center(child: CustomVideoPlayerControls()),
      ],
    );
  }
}
