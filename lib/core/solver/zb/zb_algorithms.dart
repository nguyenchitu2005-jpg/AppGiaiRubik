import '../algorithms.dart';
import '../solve_step.dart';
import 'zbll_cases.dart';
import 'zbls_cases.dart';

/// The algorithms of the ZB method (Zborowski–Bruchem): 302 ZBLS for the
/// last pair while orienting the top edges, then 472 ZBLL for the whole
/// last layer at once. From Tao Yu's Alg Trainer (MIT licence).
abstract final class ZbAlgorithms {
  static final List<Algorithm> zbls = [
    for (final c in zblsCases)
      Algorithm(
        name: 'ZBLS ${c.subset}-${c.number}',
        notation: c.notation,
        stage: SolveStage.zbls,
        group: 'Cặp F2L ${c.subset}',
        usage:
            'Trường hợp F2L ${c.subset}, biến thể ${c.number} theo hướng các '
            'cạnh vàng: đưa cặp cuối vào khe trước–phải và cùng lúc làm cả 4 '
            'cạnh tầng trên hướng lên (dấu cộng vàng).',
      ),
  ];

  static final List<Algorithm> zbll = [
    for (final c in zbllCases)
      Algorithm(
        name: 'ZBLL ${c.subset}-${c.number}',
        notation: c.notation,
        stage: SolveStage.zbll,
        group: familyOf(c.subset),
        usage:
            'Nhóm ${familyOf(c.subset)}, tập ${c.subset}: dấu cộng vàng đã '
            'có, các góc theo hình ${familyOf(c.subset)}. Xoay mặt trên (U) '
            'cho khớp hình rồi làm công thức để giải cả tầng cuối.',
      ),
  ];

  /// "T1" → "T (Chameleon)": the corner shape (as in OLL 21–27).
  static String familyOf(String subset) =>
      switch (subset.replaceAll(RegExp(r'\d'), '')) {
        'T' => 'T (Chameleon)',
        'U' => 'U (Đèn pha)',
        'L' => 'L (Bowtie)',
        'Pi' => 'Pi',
        'H' => 'H',
        'S' => 'S (Sune)',
        'AS' => 'AS (Anti-Sune)',
        final other => other,
      };
}
