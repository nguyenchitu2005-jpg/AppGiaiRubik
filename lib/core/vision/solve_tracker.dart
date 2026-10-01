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
  const TrackerCorrected(this.wrong, this.fix, {this.replanned = false});

  /// The wrong move.
  final Move wrong;

  /// The moves that undo it (to say out loud), or empty when [replanned].
  final List<Move> fix;

  /// The rest of the solution was worked out anew from where the cube is
  /// (shorter than undoing).
  final bool replanned;
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
    this.jumpHold = const Duration(milliseconds: 1200),
    this.resolve,
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

  /// Works out a solution from a position (after a wrong move, to change
  /// the formula), or null to only undo wrong moves.
  final List<Move>? Function(CubeState state)? resolve;

  /// Skipping ahead several moves at once (or straight to solved) takes a
  /// view held this long: one face alone can mislead (a misread, or the
  /// same front face as a later position), and a fast solver stays on the
  /// result anyway.
  final Duration jumpHold;

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

  /// Whether [asRead] (9 colors as the camera reads them) is the front face
  /// of a position the cube may be in now: a move or two back, a few ahead.
  /// Helps tell the cube from look-alike areas of the picture.
  bool looksExpected(List<Face> asRead) => expectedFronts.matches(asRead);

  /// The front faces [looksExpected] compares with, as plain data (to use
  /// on a background isolate).
  ExpectedFronts get expectedFronts {
    final first = (_done - 2).clamp(0, _plan.length);
    final last = (_done + lookahead).clamp(0, _plan.length);
    return ExpectedFronts(
      fronts: [for (var k = first; k <= last; k++) _front(_states[k])],
      mirrors: _mirrored == null ? const [false, true] : [_mirrored!],
      turns: cameraTurns,
    );
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
      final target = ahead.isNotEmpty ? ahead.first : matches.last;
      final jump = target - _done;
      // Skipping moves: only on an exact match, and a long jump (or one
      // to the end) only once the view holds still.
      if (jump > 1 && best < 9) return;
      if ((jump > 2 || (jump > 1 && target == _plan.length)) &&
          held < jumpHold) {
        return;
      }
      _done = target;
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

  /// Looks for the wrong move that explains what the camera sees: a move
  /// made instead of the one asked for, or an extra one, maybe followed by
  /// a move or two of the solution before the camera caught it. When one
  /// explanation is likelier than any other, the formula changes: the
  /// shorter of undoing the mistake (then going on) and a new solution
  /// from where the cube is.
  void _explain(List<Face> seen) {
    final n = _plan.length;
    // The likeliest explanation per position the cube may be in.
    final found = <CubeState, _Mistake>{};
    void consider(int k, List<Move> did, int cost) {
      final state = _states[k].applyAll(did);
      if (_score(seen, _front(state)) != 9) return;
      final known = found[state];
      if (known == null || cost < known.cost) {
        found[state] = _Mistake(k, did, cost, state);
      }
    }

    final last = (_done + 2).clamp(0, n);
    for (var k = _confirmed; k <= last; k++) {
      for (final wrong in Move.faceMoves) {
        for (var then = 0; then <= 2; then++) {
          // Instead of the move asked for (the same face turned the wrong
          // way is likeliest), then on with the solution.
          if (k < n && wrong != _plan[k] && k + 1 + then <= n) {
            consider(k, [
              wrong,
              ..._plan.sublist(k + 1, k + 1 + then),
            ], then + (wrong.layer == _plan[k].layer ? 0 : 1));
          }
          // An extra move, then on with the solution.
          if (k + then <= n) {
            consider(k, [wrong, ..._plan.sublist(k, k + then)], then + 2);
          }
        }
      }
    }
    if (found.isEmpty) {
      _lost = true;
      _news = const TrackerLost();
      return;
    }
    final best = found.values.reduce((a, b) => a.cost <= b.cost ? a : b);
    // Two different positions as likely: ask the user, do not guess.
    if (found.values.where((m) => m.cost == best.cost).length > 1) {
      _lost = true;
      _news = const TrackerLost();
      return;
    }

    // Undo what was done, then the solution from where it went wrong
    // (merging turns of the same face: R' instead of R is fixed by R2).
    final undo = _simplify([
      ...Move.invertSequence(best.did),
      ..._plan.sublist(best.k),
    ]);
    final fresh = resolve?.call(best.state);
    final replanned = fresh != null && fresh.length < undo.length;
    final rest = replanned ? fresh : undo;
    _plan = [..._plan.sublist(0, best.k), ...best.did, ...rest];
    _mistakes
      ..removeWhere((i) => i >= best.k)
      ..addAll([for (var i = 0; i < best.did.length; i++) best.k + i]);
    _replan();
    _done = _confirmed = best.k + best.did.length;
    _phase = _done == _plan.length ? TrackerPhase.solved : TrackerPhase.solving;
    // The moves to say as the fix: the undo, up to where it joins the
    // solution again (the rest is said as usual).
    final tail = n - best.k - 1 < 0 ? 0 : n - best.k - 1;
    final fix = replanned
        ? <Move>[]
        : rest.sublist(0, (rest.length - tail).clamp(0, rest.length));
    _news = TrackerCorrected(best.did.first, fix, replanned: replanned);
  }

  /// Merges neighbouring turns of the same face (R R → R2, R R' → none).
  static List<Move> _simplify(List<Move> moves) {
    final out = <Move>[];
    for (final move in moves) {
      if (out.isNotEmpty && out.last.layer == move.layer) {
        final turns = (out.last.turns + move.turns) % 4;
        out.removeLast();
        if (turns != 0) out.add(Move(move.layer, turns));
      } else {
        out.add(move);
      }
    }
    return out;
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

/// Front faces the cube may show now, and how the camera may read them.
class ExpectedFronts {
  const ExpectedFronts({
    required this.fronts,
    required this.mirrors,
    required this.turns,
  });

  final List<List<Face>> fronts;
  final List<bool> mirrors;
  final int turns;

  /// [asRead] (9 colors as the camera reads them) is one of [fronts], all
  /// but one sticker alike.
  bool matches(List<Face> asRead) {
    for (final mirror in mirrors) {
      final seen = FaceGrid.oriented(asRead, mirror: mirror, turns: turns);
      for (final front in fronts) {
        var same = 0;
        for (var i = 0; i < 9; i++) {
          if (seen[i] == front[i]) same++;
        }
        if (same >= 8) return true;
      }
    }
    return false;
  }
}

/// A wrong move found to explain what the camera sees.
class _Mistake {
  const _Mistake(this.k, this.did, this.cost, this.state);

  /// Where in the solution it happened.
  final int k;

  /// What the user did from there: the wrong move, maybe followed by moves
  /// of the solution.
  final List<Move> did;

  /// How unlikely (lower is likelier).
  final int cost;

  /// Where the cube is now.
  final CubeState state;
}
