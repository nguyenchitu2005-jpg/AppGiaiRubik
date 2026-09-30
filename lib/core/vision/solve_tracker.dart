import 'package:flutter/foundation.dart';

import '../cube/cube_state.dart';
import '../cube/face.dart';
import '../cube/move.dart';
import 'face_grid.dart';

enum TrackerPhase {
  /// Waiting to see the cube held as it was scanned.
  aligning,

  /// Following the solution move by move.
  solving,

  solved,
}

/// Something the tracker noticed, for the screen to say out loud.
sealed class TrackerNews {
  const TrackerNews();
}

/// The cube was seen held the right way: the solve starts.
class TrackerStarted extends TrackerNews {
  const TrackerStarted();
}

/// Moves were seen done (maybe several at once, for a fast solver).
class TrackerAdvanced extends TrackerNews {
  const TrackerAdvanced(this.count);

  final int count;
}

/// The cube shows an earlier position again (a move undone).
class TrackerWentBack extends TrackerNews {
  const TrackerWentBack();
}

/// The user turned [wrong] instead of the move asked for; [fix] undoes it
/// and continues (already put into the plan).
class TrackerCorrected extends TrackerNews {
  const TrackerCorrected(this.wrong, this.fix);

  final Move wrong;
  final List<Move> fix;
}

/// The camera sees a position that no expected or single wrong move
/// explains.
class TrackerLost extends TrackerNews {
  const TrackerLost();
}

class TrackerSolved extends TrackerNews {
  const TrackerSolved();
}

/// Follows a solution being played on a real cube through the camera.
///
/// The camera sees one face: the front, held toward it (as when the first
/// face was scanned). After every move the front face should show what the
/// solution predicts. Frames whose 9 colors hold still are compared with
/// the positions a few moves ahead (a fast solver may be ahead of the
/// voice), and when none match, with the positions one wrong move away,
/// so a mistake can be undone.
///
/// Some moves do not change the front face (a turn of the back): the
/// camera cannot see them. [confirmByUser] steps over them (the screen
/// does this after a pause); the next visible move then confirms them.
class SolveTracker extends ChangeNotifier {
  SolveTracker({
    required this.start,
    required List<Move> solution,
    this.preferMirrored = false,
    this.cameraTurns = 0,
    this.stableFor = const Duration(milliseconds: 250),
    this.minFrames = 2,
    this.lostAfter = const Duration(milliseconds: 1500),
    this.lookahead = 4,
  }) : _plan = List.of(solution) {
    _replan();
    if (_plan.isEmpty) _phase = TrackerPhase.solved;
  }

  final CubeState start;

  /// The scan found the camera mirrors its pictures: when a face reads the
  /// same both ways, assume it mirrors.
  final bool preferMirrored;

  /// Clockwise quarter turns that put a camera grid upright (see
  /// ScanResult.cameraTurns).
  final int cameraTurns;

  /// Colors must hold still this long, over at least [minFrames] frames,
  /// before they are compared (a hand in the way, a face half turned).
  final Duration stableFor;
  final int minFrames;

  /// A still, clear front face that matches nothing for this long is a
  /// mistake to explain.
  final Duration lostAfter;

  /// How many moves ahead of the voice the solver may be.
  final int lookahead;

  List<Move> _plan;
  late List<CubeState> _states;
  final Set<int> _mistakes = {};
  int _done = 0;
  int _confirmed = 0;
  bool? _mirrored;
  var _phase = TrackerPhase.aligning;
  bool _lost = false;
  List<Face>? _explained;
  TrackerNews? _news;
  final List<_Frame> _frames = [];

  TrackerPhase get phase => _phase;

  /// The moves to make, including the user's wrong moves and their fixes.
  List<Move> get plan => List.unmodifiable(_plan);

  /// Plan indices that were the user's wrong moves.
  Set<int> get mistakes => Set.unmodifiable(_mistakes);

  /// Moves done so far (seen by the camera, or stepped over by the user).
  int get done => _done;

  /// The move to make now, or null when solved.
  Move? get current => _done < _plan.length ? _plan[_done] : null;

  /// The position the cube should be in now.
  CubeState get expected => _states[_done];

  /// The camera can see [current] being made (it changes the front face).
  bool get currentIsVisible =>
      current != null &&
      !listEquals(_front(_states[_done]), _front(_states[_done + 1]));

  /// The camera shows a position nothing explains.
  bool get isLost => _lost;

  /// The camera shows another face than the front one (the cube is held
  /// the wrong way, or turned to look at it).
  bool get wrongFace {
    final labels = _oriented;
    return labels != null && labels[4] != start.center(Face.f);
  }

  /// The latest colors seen, put the way the front face is (null until the
  /// camera's orientation is known).
  List<Face>? get _oriented {
    if (_frames.isEmpty) return null;
    return _orient(_frames.last.labels, _mirrored ?? preferMirrored);
  }

  /// The latest news, taken once.
  TrackerNews? takeNews() {
    final news = _news;
    _news = null;
    return news;
  }

  /// [labels]: the colors seen in the camera grid, row by row as read.
  /// [clear]: every sticker read clearly.
  void addFrame(List<Face> labels, Duration time, {bool clear = true}) {
    _frames
      ..add(_Frame(time, labels, clear))
      ..removeWhere((f) => time - f.time > lostAfter * 2);
    if (_phase == TrackerPhase.solved) return;
    final held = _heldFor(time);
    if (held == null) {
      notifyListeners();
      return;
    }
    if (_phase == TrackerPhase.aligning) {
      _align(labels, held);
    } else {
      _follow(_orient(labels, _mirrored ?? preferMirrored), held);
    }
    notifyListeners();
  }

  /// Starts without waiting to see the cube held right.
  void startAnyway() {
    if (_phase != TrackerPhase.aligning) return;
    _phase = TrackerPhase.solving;
    _news = const TrackerStarted();
    notifyListeners();
  }

  /// The user says the current move is done (one the camera cannot see, or
  /// when the camera is not helping).
  void confirmByUser() {
    if (_phase != TrackerPhase.solving) return;
    _done++;
    _lost = false;
    _news = _done == _plan.length ? const TrackerSolved() : null;
    if (_done == _plan.length) _phase = TrackerPhase.solved;
    notifyListeners();
  }

  /// Goes back one move (the user tapped past one by mistake).
  void back() {
    if (_done == 0) return;
    _done--;
    if (_confirmed > _done) _confirmed = _done;
    _phase = TrackerPhase.solving;
    _lost = false;
    notifyListeners();
  }

  /// How long the latest colors have been clear and unchanged, or null
  /// while they are not yet stable.
  Duration? _heldFor(Duration now) {
    final latest = _frames.last;
    if (!latest.clear) return null;
    var start = _frames.length - 1;
    while (start > 0 &&
        _frames[start - 1].clear &&
        listEquals(_frames[start - 1].labels, latest.labels)) {
      start--;
    }
    final held = now - _frames[start].time;
    final count = _frames.length - start;
    return count >= minFrames && held >= stableFor ? held : null;
  }

  void _align(List<Face> labels, Duration held) {
    final front = _front(start);
    final plain = _score(_orient(labels, false), front);
    final flipped = _score(_orient(labels, true), front);
    if (plain == 9 || flipped == 9) {
      _mirrored = plain == 9 && flipped == 9 ? preferMirrored : flipped == 9;
      _phase = _plan.isEmpty ? TrackerPhase.solved : TrackerPhase.solving;
      _lost = false;
      _news = const TrackerStarted();
      return;
    }
    _lost = labels[4] == start.center(Face.f) && held >= lostAfter;
  }

  void _follow(List<Face> seen, Duration held) {
    // Positions the cube may be in: a move or two undone, up to a few
    // moves ahead of the voice.
    final first = _confirmed < _done - 2 ? _confirmed : _done - 2;
    final last = (_done + lookahead).clamp(0, _plan.length);
    var best = 0;
    final matches = <int>[];
    for (var k = first < 0 ? 0 : first; k <= last; k++) {
      final score = _score(seen, _front(_states[k]));
      if (score > best) {
        best = score;
        matches.clear();
      }
      if (score == best) matches.add(k);
    }

    if (best >= 8) {
      _lost = false;
      if (matches.contains(_done)) {
        // Nothing new (or only moves the camera cannot tell apart).
        if (matches.length == 1) _confirmed = _done;
        return;
      }
      final before = _done;
      // Rather ahead than behind; the nearest such position.
      final ahead = matches.where((k) => k > _done);
      _done = ahead.isNotEmpty ? ahead.first : matches.last;
      _confirmed = _done;
      if (_done == _plan.length) {
        _phase = TrackerPhase.solved;
        _news = const TrackerSolved();
      } else {
        _news = _done > before
            ? TrackerAdvanced(_done - before)
            : const TrackerWentBack();
      }
      return;
    }

    // The front face is not showing (turned away): nothing to judge.
    if (seen[4] != start.center(Face.f) || held < lostAfter) return;
    // Each still view is explained once.
    if (listEquals(seen, _explained)) return;
    _explained = seen;
    _explain(seen);
  }

  /// Looks for the one wrong move that explains what the camera sees.
  void _explain(List<Face> seen) {
    final found = <CubeState, (int, Move)>{};
    for (var k = _confirmed; k <= _done; k++) {
      for (final move in Move.faceMoves) {
        if (k < _plan.length && move == _plan[k]) continue;
        final state = _states[k].apply(move);
        if (_score(seen, _front(state)) == 9) found[state] ??= (k, move);
      }
    }
    if (found.length != 1) {
      _lost = true;
      _news = const TrackerLost();
      return;
    }
    final (k, wrong) = found.values.single;
    // Undo the wrong move, then make the one asked for (merged when both
    // turn the same layer: R' instead of R is fixed by R2).
    final fix = k == _plan.length
        ? [wrong.inverse]
        : wrong.layer == _plan[k].layer
        ? [Move(wrong.layer, (_plan[k].turns - wrong.turns) % 4)]
        : [wrong.inverse, _plan[k]];
    _plan = [
      ..._plan.sublist(0, k),
      wrong,
      ...fix,
      ..._plan.sublist(k == _plan.length ? k : k + 1),
    ];
    final shift = fix.length;
    final shifted = {for (final i in _mistakes) i > k ? i + shift : i};
    _mistakes
      ..clear()
      ..addAll(shifted)
      ..add(k);
    _replan();
    _done = _confirmed = k + 1;
    _phase = TrackerPhase.solving;
    _news = TrackerCorrected(wrong, fix);
  }

  void _replan() {
    _states = [start];
    for (final move in _plan) {
      _states.add(_states.last.apply(move));
    }
  }

  List<Face> _orient(List<Face> labels, bool mirror) =>
      FaceGrid.oriented(labels, mirror: mirror, turns: cameraTurns);

  static List<Face> _front(CubeState state) => [
    for (var i = 0; i < 9; i++) state[Face.f.offset + i],
  ];

  static int _score(List<Face> a, List<Face> b) {
    var same = 0;
    for (var i = 0; i < 9; i++) {
      if (a[i] == b[i]) same++;
    }
    return same;
  }
}

class _Frame {
  const _Frame(this.time, this.labels, this.clear);

  final Duration time;
  final List<Face> labels;
  final bool clear;
}
