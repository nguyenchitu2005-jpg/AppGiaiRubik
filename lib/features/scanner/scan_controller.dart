import 'dart:math';

import 'package:flutter/foundation.dart';

import '../../core/cube/face.dart';
import '../../core/vision/color_classifier.dart';
import '../../core/vision/color_math.dart';
import '../../core/vision/scan_assembler.dart';

/// One face to scan and how to hold the cube for it. The holds match the
/// unfolded net, so each camera grid maps straight onto facelets.
class ScanStep {
  const ScanStep(this.face, this.instruction);

  final Face face;
  final String instruction;
}

/// Walks the user through scanning six faces from a stream of camera
/// samples (9 colors per frame).
class ScanController extends ChangeNotifier {
  static const steps = [
    ScanStep(
      Face.f,
      'Cầm khối với tâm trắng ở trên. Đưa mặt có tâm xanh lá về phía camera.',
    ),
    ScanStep(
      Face.r,
      'Xoay cả khối sang trái một góc vuông (trắng vẫn ở trên): mặt tâm đỏ '
      'về phía camera.',
    ),
    ScanStep(
      Face.b,
      'Xoay tiếp sang trái một góc vuông: mặt tâm xanh dương về phía camera.',
    ),
    ScanStep(
      Face.l,
      'Xoay tiếp sang trái một góc vuông: mặt tâm cam về phía camera.',
    ),
    ScanStep(
      Face.u,
      'Xoay tiếp sang trái để mặt xanh lá về phía trước, rồi lật mặt trên về '
      'phía bạn: mặt tâm trắng về phía camera, mặt xanh dương ở trên.',
    ),
    ScanStep(
      Face.d,
      'Lật khối nửa vòng theo chiều dọc: mặt tâm vàng về phía camera, mặt xanh lá '
      'ở trên.',
    ),
  ];

  /// Colors must stay the same this long before a face can be captured.
  static const stableFor = Duration(milliseconds: 500);

  /// A clearly read face showing the expected center is captured by itself
  /// once held still this long.
  static const autoCaptureAfter = Duration(milliseconds: 900);

  /// Capture faces by themselves (see [autoCaptureAfter]).
  bool autoCapture = true;

  final Map<Face, List<Rgb>> _captured = {};
  final List<_Frame> _frames = [];
  int _stepIndex = 0;
  bool _stable = false;

  int get stepIndex => _stepIndex;

  bool get isComplete => _stepIndex == steps.length;

  ScanStep? get step => isComplete ? null : steps[_stepIndex];

  /// Latest per-sticker guess, or null before the first frame.
  List<Face>? get live => _frames.isEmpty ? null : _frames.last.labels;

  /// The guesses have not changed for [stableFor].
  bool get isStable => _stable;

  /// The live center matches the face we asked for (a hint that the right
  /// face is in the frame).
  bool get centerMatches => live == null || live![4] == step?.face;

  /// Every sticker of the latest frame reads clearly (no gap, shadow or
  /// color on the edge between two).
  bool get isClear =>
      _frames.isNotEmpty &&
      _frames.last.samples.every(LiveColorClassifier.isClear);

  /// How far along the hold before an automatic capture is (0–1).
  double autoProgress(Duration now) {
    if (!autoCapture || _frames.isEmpty || !isClear || !centerMatches) {
      return 0;
    }
    final held = now - _stableRun.first.time;
    return (held.inMilliseconds / autoCaptureAfter.inMilliseconds).clamp(
      0.0,
      1.0,
    );
  }

  /// Captured faces as best guesses, for a small preview.
  Map<Face, List<Face>> get capturedPreview => {
    for (final entry in _captured.entries)
      entry.key: [for (final c in entry.value) _label(c)],
  };

  /// A sticker's color, telling apart the colors a camera mixes up by this
  /// cube's own centers once scanned:
  /// - red and orange: a salmon orange under a bright webcam has a red's
  ///   hue;
  /// - white and yellow: a yellow washed out by bright light looks white,
  ///   a white under warm light looks cream.
  /// The center of the face being scanned is the color asked for unless it
  /// looks like the other one already scanned.
  Face _label(Rgb color, {bool center = false}) {
    final guess = LiveColorClassifier.classify(color);
    for (final (a, b, distance, same) in _lookAlikes) {
      if (guess != a && guess != b) continue;
      final ra = _captured[a]?[4], rb = _captured[b]?[4];
      if (ra != null && rb != null) {
        return distance(color, ra) <= distance(color, rb) ? a : b;
      }
      // Close enough to a scanned center to be its color.
      if (ra != null) return distance(color, ra) <= same ? a : b;
      if (rb != null) return distance(color, rb) <= same ? b : a;
      final asked = step?.face;
      if (center && (asked == a || asked == b)) return asked!;
      return guess;
    }
    return guess;
  }

  /// Pairs of colors told apart by the scanned centers, how to compare two
  /// stickers of them, and how close is the same color.
  static final _lookAlikes = <(Face, Face, double Function(Rgb, Rgb), double)>[
    (Face.r, Face.l, LiveColorClassifier.redOrangeDistance, 1.5),
    (Face.u, Face.d, _chromaDistance, 0.02),
  ];

  static double _chromaDistance(Rgb a, Rgb b) {
    final (ar, ag) = a.chromaticity;
    final (br, bg) = b.chromaticity;
    return sqrt((ar - br) * (ar - br) + (ag - bg) * (ag - bg));
  }

  void addFrame(List<Rgb> samples, Duration time) {
    if (isComplete) return;
    final labels = [
      for (var i = 0; i < samples.length; i++)
        _label(samples[i], center: i == 4),
    ];
    _frames
      ..add(_Frame(time, labels, samples))
      ..removeWhere((f) => time - f.time > stableFor * 3);
    _stable = time - _stableRun.first.time >= stableFor;
    // The face is read: the right center, every sticker clear, held still.
    // (Until the cube is turned, the center no longer matches the next
    // face, so the same face is not captured twice.)
    if (autoCapture &&
        _stable &&
        live![4] == step!.face &&
        isClear &&
        time - _stableRun.first.time >= autoCaptureAfter) {
      capture();
      return;
    }
    notifyListeners();
  }

  /// Records the current face from the average of its stable frames.
  void capture() {
    if (!_stable || isComplete) return;
    final run = _stableRun;
    _captured[step!.face] = [
      for (var i = 0; i < 9; i++)
        Rgb.average([for (final f in run) f.samples[i]]),
    ];
    _stepIndex++;
    _reset();
  }

  /// Records the current face from a single photo's colors (where the
  /// camera has no live frames: web, Windows).
  void captureSamples(List<Rgb> samples) {
    if (isComplete) return;
    _captured[step!.face] = samples;
    _stepIndex++;
    _reset();
  }

  /// The face went out of sight: what was seen no longer holds still.
  void lostSight() {
    if (_frames.isEmpty) return;
    _reset();
  }

  void retakePrevious() {
    if (_stepIndex == 0) return;
    _stepIndex--;
    _captured.remove(steps[_stepIndex].face);
    _reset();
  }

  ScanResult assemble() {
    if (!isComplete) throw StateError('Chưa quét đủ 6 mặt');
    return ScanAssembler.assemble(_captured);
  }

  /// Trailing frames whose guesses equal the latest ones.
  List<_Frame> get _stableRun {
    final latest = _frames.last.labels;
    var start = _frames.length - 1;
    while (start > 0 && listEquals(_frames[start - 1].labels, latest)) {
      start--;
    }
    return _frames.sublist(start);
  }

  void _reset() {
    _frames.clear();
    _stable = false;
    notifyListeners();
  }
}

class _Frame {
  const _Frame(this.time, this.labels, this.samples);

  final Duration time;
  final List<Face> labels;
  final List<Rgb> samples;
}
