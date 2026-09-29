import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../state/settings.dart';

/// The cube's sound effects. Sound is a nicety: playing never throws, and a
/// platform that cannot play simply stays silent.
abstract interface class CubeSounds {
  /// One layer turning (and clicking into place).
  void turn();

  /// A quick run of turns, for a new scramble.
  void scramble();
}

/// [CubeSounds] with audioplayers (Android, iOS, Windows, macOS, web).
class AudioCubeSounds implements CubeSounds {
  // Turns overlap when they come fast (quick autoplay), so they share a pool.
  Future<AudioPool>? _turns;
  AudioPlayer? _scramble;
  Future<void>? _configured;

  /// Game sounds mix with whatever else is playing: a click must not pause
  /// the user's music (the default takes the audio focus). On iOS they also
  /// follow the silent switch.
  static Future<void> _configure() async {
    if (kIsWeb) return;
    try {
      await AudioPlayer.global.setAudioContext(
        AudioContext(
          android: const AudioContextAndroid(
            contentType: AndroidContentType.sonification,
            usageType: AndroidUsageType.game,
            audioFocus: AndroidAudioFocus.none,
          ),
          iOS: AudioContextIOS(category: AVAudioSessionCategory.ambient),
        ),
      );
    } catch (error) {
      // Desktop platforms have no audio focus to configure.
      debugPrint('Không cấu hình được âm thanh: $error');
    }
  }

  @override
  void turn() => _guard(() async {
    await (_configured ??= _configure());
    final pool = await (_turns ??= AudioPool.createFromAsset(
      path: 'sounds/turn.wav',
      maxPlayers: 4,
    ));
    await pool.start(volume: 0.8);
  });

  @override
  void scramble() => _guard(() async {
    await (_configured ??= _configure());
    final player = _scramble ??= AudioPlayer();
    await player.stop();
    await player.play(AssetSource('sounds/scramble.wav'));
  });

  void _guard(Future<void> Function() play) {
    play().catchError((Object error) {
      debugPrint('Không phát được âm thanh: $error');
    });
  }

  Future<void> dispose() async {
    await (await _turns)?.dispose();
    await _scramble?.dispose();
  }
}

final cubeSoundsProvider = Provider<CubeSounds>((ref) {
  final sounds = AudioCubeSounds();
  ref.onDispose(sounds.dispose);
  return sounds;
});

/// Plays the sounds only while they are switched on in the settings.
extension CubeSoundsRef on WidgetRef {
  void playTurnSound() {
    if (read(soundEnabledProvider)) read(cubeSoundsProvider).turn();
  }

  void playScrambleSound() {
    if (read(soundEnabledProvider)) read(cubeSoundsProvider).scramble();
  }
}
