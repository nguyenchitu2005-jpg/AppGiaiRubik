/// A penalty given to a timed solve (WCA rules).
enum Penalty { none, plus2, dnf }

/// One timed solve.
class TimedSolve {
  const TimedSolve({
    required this.millis,
    required this.scramble,
    required this.at,
    this.penalty = Penalty.none,
  });

  factory TimedSolve.fromJson(Map<String, Object?> json) => TimedSolve(
    millis: json['ms']! as int,
    scramble: json['scramble']! as String,
    at: DateTime.fromMillisecondsSinceEpoch(json['at']! as int),
    penalty: Penalty.values.byName(json['penalty']! as String),
  );

  /// Time on the clock, without the penalty.
  final int millis;
  final String scramble;
  final DateTime at;
  final Penalty penalty;

  bool get isDnf => penalty == Penalty.dnf;

  /// Time that counts (+2 seconds added), null for a DNF.
  int? get result => switch (penalty) {
    Penalty.none => millis,
    Penalty.plus2 => millis + 2000,
    Penalty.dnf => null,
  };

  TimedSolve withPenalty(Penalty penalty) =>
      TimedSolve(millis: millis, scramble: scramble, at: at, penalty: penalty);

  Map<String, Object?> toJson() => {
    'ms': millis,
    'scramble': scramble,
    'at': at.millisecondsSinceEpoch,
    'penalty': penalty.name,
  };
}

/// Statistics over solves listed oldest first.
abstract final class SolveStats {
  static int? best(List<TimedSolve> solves) {
    int? best;
    for (final s in solves) {
      final r = s.result;
      if (r != null && (best == null || r < best)) best = r;
    }
    return best;
  }

  /// Mean of every solve that is not a DNF.
  static int? mean(List<TimedSolve> solves) {
    final results = [for (final s in solves) ?s.result];
    if (results.isEmpty) return null;
    return (results.reduce((a, b) => a + b) / results.length).round();
  }

  /// WCA average of the last [n] solves (Ao5, Ao12): the best and the worst
  /// are dropped (a DNF counts as the worst), the rest averaged. Null if
  /// there are fewer than [n] solves; [dnf] if more than one is a DNF.
  static int? averageOf(int n, List<TimedSolve> solves) {
    if (solves.length < n) return null;
    final last = solves.sublist(solves.length - n);
    final trim = n >= 12 ? (n * 0.05).ceil() : 1;
    final dnfs = last.where((s) => s.isDnf).length;
    if (dnfs > trim) return dnf;
    // DNFs (null) sort last, as the worst.
    final sorted = [for (final s in last) s.result]
      ..sort(
        (a, b) => switch ((a, b)) {
          (null, null) => 0,
          (null, _) => 1,
          (_, null) => -1,
          (final a?, final b?) => a.compareTo(b),
        },
      );
    final counted = [for (final r in sorted.sublist(trim, n - trim)) r!];
    return (counted.reduce((a, b) => a + b) / counted.length).round();
  }

  /// Marks an average made void by DNFs.
  static const int dnf = -1;

  /// "9.87", "1:02.35", "DNF"; "11.87+" for a +2 when given the solve.
  static String format(int? millis, {Penalty penalty = Penalty.none}) {
    if (penalty == Penalty.dnf || millis == dnf) return 'DNF';
    if (millis == null) return '–';
    final shown = penalty == Penalty.plus2 ? millis + 2000 : millis;
    final centis = shown ~/ 10;
    final minutes = centis ~/ 6000;
    final seconds = centis ~/ 100 % 60;
    final hundredths = (centis % 100).toString().padLeft(2, '0');
    final time = minutes > 0
        ? '$minutes:${seconds.toString().padLeft(2, '0')}.$hundredths'
        : '$seconds.$hundredths';
    return penalty == Penalty.plus2 ? '$time+' : time;
  }
}
