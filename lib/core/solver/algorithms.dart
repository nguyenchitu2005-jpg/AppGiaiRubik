import '../cube/move.dart';
import 'solve_step.dart';

/// A named move sequence used by one of the methods.
class Algorithm {
  const Algorithm({
    required this.name,
    required this.notation,
    required this.stage,
    required this.usage,
    this.group,
  });

  final String name;
  final String notation;
  final SolveStage stage;

  /// When and how to use it, in Vietnamese.
  final String usage;

  /// The family of cases it belongs to (OLL/PLL), if any.
  final String? group;

  List<Move> get moves => Move.parseSequence(notation);
}

/// Every algorithm the beginner method needs, in the order it is learned.
abstract final class Algorithms {
  static const trigger = Algorithm(
    name: "R U R' U'",
    notation: "R U R' U'",
    stage: SolveStage.whiteCorners,
    usage:
        'Góc trắng nằm ngay trên ô đích (trước–phải, tầng trên): lặp công '
        'thức này đến khi góc về đúng chỗ, màu trắng ở dưới (tối đa 5 lần).',
  );

  static const rightInsert = Algorithm(
    name: 'Công thức phải',
    notation: "U R U' R' U' F' U F",
    stage: SolveStage.middleLayer,
    usage:
        'Cạnh ở mặt trước tầng trên đã khớp màu với tâm mặt trước, màu còn '
        'lại trùng tâm mặt phải: đưa cạnh xuống tầng giữa bên phải.',
  );

  static const leftInsert = Algorithm(
    name: 'Công thức trái',
    notation: "U' L' U L U F U' F'",
    stage: SolveStage.middleLayer,
    usage:
        'Như công thức phải, nhưng màu còn lại trùng tâm mặt trái: đưa cạnh '
        'xuống tầng giữa bên trái.',
  );

  static const yellowCross = Algorithm(
    name: 'Dấu cộng vàng',
    notation: "F R U R' U' F'",
    stage: SolveStage.yellowCross,
    usage:
        'Mặt trên có chấm, chữ L (đặt ở góc sau–trái) hoặc đường thẳng (nằm '
        'ngang): làm công thức, lặp lại đến khi có dấu cộng vàng.',
  );

  static const sune = Algorithm(
    name: 'Sune',
    notation: "R U R' U R U2 R'",
    stage: SolveStage.yellowFace,
    usage:
        'Có dấu cộng vàng nhưng các góc chưa vàng. Nếu có 1 góc vàng (hình '
        'con cá), đặt nó ở trước–trái rồi làm Sune; lặp đến khi mặt trên vàng.',
  );

  static const aPerm = Algorithm(
    name: 'A-perm',
    notation: "R' F R' B2 R F' R' B2 R2",
    stage: SolveStage.lastLayerCorners,
    usage:
        'Đổi chỗ 3 góc tầng trên. Tìm mặt có 2 góc cùng màu (đèn pha), đặt '
        'nó ở mặt sau rồi làm công thức; không có thì làm một lần rồi tìm lại.',
  );

  static const uPerm = Algorithm(
    name: 'U-perm',
    notation: "R U' R U R U R U' R' U' R2",
    stage: SolveStage.lastLayerEdges,
    usage:
        'Đổi chỗ 3 cạnh tầng trên. Đặt mặt đã hoàn chỉnh ở phía sau rồi làm '
        'công thức (có thể phải làm 2 lần).',
  );

  static const all = [
    trigger,
    rightInsert,
    leftInsert,
    yellowCross,
    sune,
    aPerm,
    uPerm,
  ];
}
