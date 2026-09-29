import '../cube/face.dart';
import '../cube/move.dart';

/// The stages of the layer-by-layer beginner method, plus the initial
/// "hold the cube" step.
enum SolveStage {
  hold(
    'Cầm khối',
    'Lật khối để tâm trắng ở dưới, tâm vàng ở trên. Giữ hướng cầm này '
        'cho các bước sau.',
  ),
  whiteCross(
    'Dấu cộng trắng',
    'Tạo dấu cộng trắng ở mặt dưới. Màu còn lại của mỗi cạnh phải trùng với '
        'tâm của mặt bên.',
  ),
  whiteCorners(
    'Góc tầng 1',
    'Đưa từng góc trắng lên ngay trên vị trí của nó (trước–phải), rồi lặp '
        "R U R' U' đến khi góc về đúng chỗ.",
  ),
  middleLayer(
    'Tầng 2',
    'Đưa từng cạnh không có màu vàng từ tầng trên xuống tầng giữa bằng công '
        'thức trái hoặc phải.',
  ),
  yellowCross(
    'Dấu cộng vàng',
    "Dùng F R U R' U' F' để tạo dấu cộng vàng ở mặt trên.",
  ),
  yellowFace(
    'Mặt vàng',
    "Dùng Sune (R U R' U R U2 R') để cả mặt trên thành màu vàng.",
  ),
  lastLayerCorners(
    'Đặt góc tầng 3',
    'Đưa 4 góc tầng trên về đúng vị trí bằng A-perm.',
  ),
  lastLayerEdges(
    'Đặt cạnh tầng 3',
    'Đưa 4 cạnh tầng trên về đúng vị trí bằng U-perm. Khối được giải!',
  ),

  /// Not part of the beginner method: a short computer-found solution.
  quick(
    'Lời giải ngắn',
    'Lời giải khoảng 20 bước tìm bằng thuật toán Kociemba. Ngắn nhưng khó '
        'nhớ: hãy làm theo từng nước.',
  );

  /// The seven stages of the beginner method, in order.
  static const learning = [
    whiteCross,
    whiteCorners,
    middleLayer,
    yellowCross,
    yellowFace,
    lastLayerCorners,
    lastLayerEdges,
  ];

  const SolveStage(this.title, this.goal);

  final String title;

  /// What this stage achieves and how, in one or two sentences.
  final String goal;

  /// 1-based stage number as shown to the user (0 for [hold]).
  int get number => index;
}

/// One instruction of a solution: a short move sequence with its purpose.
class SolveStep {
  const SolveStep({
    required this.stage,
    required this.moves,
    required this.explanation,
    this.formula,
    this.focus,
  });

  final SolveStage stage;
  final List<Move> moves;

  /// What this step does, in Vietnamese.
  final String explanation;

  /// Name of the algorithm used, if any (e.g. "Sune").
  final String? formula;

  /// Colors of the piece this step works on, to highlight it.
  final Set<Face>? focus;

  @override
  String toString() => '[${stage.title}] ${Move.format(moves)} — $explanation';
}
