import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/solver/algorithms.dart';
import '../core/solver/scrambles.dart';

/// The kinds of cases that can be practised, in menu order.
const practiceKinds = [
  ScrambleKind.f2l,
  ScrambleKind.oll,
  ScrambleKind.pll,
  ScrambleKind.zbls,
  ScrambleKind.zbll,
];

/// Which cases of each kind are practised. Everything is, until the user
/// leaves some out; the left-out names are what is stored.
class PracticeSelectionController
    extends Notifier<Map<ScrambleKind, Set<String>>> {
  @override
  Map<ScrambleKind, Set<String>> build() => const {};

  Set<String> _excluded(ScrambleKind kind) => state[kind] ?? const {};

  bool isSelected(ScrambleKind kind, Algorithm algorithm) =>
      !_excluded(kind).contains(algorithm.name);

  /// The cases of [kind] being practised.
  List<Algorithm> selected(ScrambleKind kind) => [
    for (final a in kind.algorithms)
      if (!_excluded(kind).contains(a.name)) a,
  ];

  /// Includes or leaves out [algorithms] (a case or a whole group).
  void set(ScrambleKind kind, Iterable<Algorithm> algorithms, bool selected) {
    final excluded = {..._excluded(kind)};
    for (final a in algorithms) {
      selected ? excluded.remove(a.name) : excluded.add(a.name);
    }
    state = {...state, kind: excluded};
  }
}

final practiceSelectionProvider =
    NotifierProvider<
      PracticeSelectionController,
      Map<ScrambleKind, Set<String>>
    >(PracticeSelectionController.new);

/// One timed practice solve.
class PracticeAttempt {
  const PracticeAttempt(this.kind, this.caseName, this.millis);

  final ScrambleKind kind;
  final String caseName;
  final int millis;
}

/// This session's practice solves, oldest first.
class PracticeSessionController extends Notifier<List<PracticeAttempt>> {
  @override
  List<PracticeAttempt> build() => const [];

  void add(PracticeAttempt attempt) => state = [...state, attempt];

  void clear(ScrambleKind kind) => state = [
    for (final a in state)
      if (a.kind != kind) a,
  ];
}

final practiceSessionProvider =
    NotifierProvider<PracticeSessionController, List<PracticeAttempt>>(
      PracticeSessionController.new,
    );
