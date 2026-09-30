import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tts/flutter_tts.dart';

import '../core/cube/move.dart';
import '../core/cube/move_description.dart';

/// Something to say, in Vietnamese and (for devices without a Vietnamese
/// voice) in English.
class Speech {
  const Speech(this.vi, this.en);

  /// A move as cubers read it: "R phẩy", "U hai" ("R prime", "U two"),
  /// with how to turn it when [explain] is on.
  factory Speech.move(Move move, {bool explain = false}) {
    final letter = move.layer.symbol.toUpperCase();
    final wide = move.layer.depth == LayerDepth.wide;
    final vi =
        '$letter${wide ? ' kép' : ''}'
        '${const ['', '', ' hai', ' phẩy'][move.turns]}';
    final en =
        '$letter${wide ? ' wide' : ''}'
        '${const ['', '', ' two', ' prime'][move.turns]}';
    return Speech(explain ? '$vi. ${move.description}.' : vi, en);
  }

  final String vi;
  final String en;
}

/// Reads instructions aloud. Speaking is a nicety: it never throws, and a
/// device without speech stays silent.
abstract interface class Speaker {
  /// Says [speech], cutting off whatever is still being said.
  void say(Speech speech);

  void stop();
}

/// [Speaker] with the platform's text-to-speech (Android, iOS, Windows,
/// macOS, browsers).
class TtsSpeaker implements Speaker {
  final FlutterTts _tts = FlutterTts();
  Future<void>? _ready;
  bool _vietnamese = false;

  Future<void> _setUp() async {
    await _tts.awaitSpeakCompletion(false);
    // Short words, said a little quicker than normal (the rate's scale
    // differs: a browser's normal is 1, the others' 0.5).
    await _tts.setSpeechRate(kIsWeb ? 1.15 : 0.58);
    await _tts.setVolume(1);
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
      // Mix with the user's music instead of stopping it.
      await _tts.setIosAudioCategory(IosTextToSpeechAudioCategory.playback, [
        IosTextToSpeechAudioCategoryOptions.mixWithOthers,
      ]);
    }
    await _chooseLanguage();
  }

  Future<void> _chooseLanguage() async {
    final languages = await _tts.getLanguages;
    final names = [
      if (languages is List)
        for (final l in languages) l.toString().toLowerCase(),
    ];
    _vietnamese = names.any((l) => l.startsWith('vi'));
    await _tts.setLanguage(_vietnamese ? 'vi-VN' : 'en-US');
  }

  @override
  void say(Speech speech) => _guard(() async {
    await (_ready ??= _setUp());
    // A browser lists its voices only after a moment.
    if (!_vietnamese && kIsWeb) await _chooseLanguage();
    await _tts.stop();
    await _tts.speak(_vietnamese ? speech.vi : speech.en);
  });

  @override
  void stop() => _guard(() async {
    if (_ready != null) await _tts.stop();
  });

  void _guard(Future<void> Function() speak) {
    speak().catchError((Object error) {
      debugPrint('Không đọc được thành tiếng: $error');
    });
  }
}

final speakerProvider = Provider<Speaker>((ref) {
  final speaker = TtsSpeaker();
  ref.onDispose(speaker.stop);
  return speaker;
});
