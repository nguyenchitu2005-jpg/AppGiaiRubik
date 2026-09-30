import '../cube/face.dart';
import '../cube/move.dart';

/// The stages of the two human methods (layer by layer for beginners, CFOP
/// for speed), plus the initial "hold the cube" step.
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

  cross(
    'Cross',
    'Làm dấu cộng trắng ở mặt dưới trong một lần: tính trước đường đi của '
        'cả 4 cạnh (người giải nhanh làm trong tối đa 8 nước).',
  ),
  f2l(
    'F2L',
    'First Two Layers: ghép góc trắng với cạnh cùng màu thành một cặp ở '
        'tầng trên rồi đưa cả cặp vào khe. 4 cặp xong là xong 2 tầng dưới.',
  ),
  oll(
    'OLL',
    'Orientation of the Last Layer: một công thức (trong 57) làm cả mặt '
        'trên thành màu vàng.',
  ),
  pll(
    'PLL',
    'Permutation of the Last Layer: một công thức (trong 21) đưa các mảnh '
        'tầng trên về đúng chỗ. Khối được giải!',
  ),

  zbls(
    'ZBLS',
    'Zborowski–Bruchem Last Slot: đưa cặp cuối vào khe và cùng lúc làm cả '
        '4 cạnh tầng trên hướng lên (dấu cộng vàng), một công thức trong 302.',
  ),
  zbll(
    'ZBLL',
    'Zborowski–Bruchem Last Layer: giải cả tầng cuối trong một công thức '
        '(trong 472) khi đã có dấu cộng vàng. Khối được giải!',
  ),

  /// Not a human method: a short computer-found solution.
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

  /// The four stages of CFOP, in order.
  static const cfop = [cross, f2l, oll, pll];

  /// The ZB method: CFOP's start, then ZBLS and ZBLL.
  static const zb = [cross, f2l, zbls, zbll];

  const SolveStage(this.title, this.goal);

  final String title;

  /// What this stage achieves and how, in one or two sentences.
  final String goal;

  /// 1-based stage number as shown to the user (0 for [hold]).
  int get number => index;
}

/// A way of solving the cube by hand, matched to the solver's level.
enum SolveMethod {
  beginner(
    level: 'Newbie',
    name: 'Phương pháp tầng',
    fullName: 'Phương pháp tầng (Layer by Layer)',
    formulas: 'Công thức cơ bản',
    summary:
        'Giải từng tầng từ dưới lên với 7 công thức dễ nhớ. Khoảng 100–150 '
        'nước, hợp với người mới bắt đầu.',
    stages: SolveStage.learning,
  ),
  cfop(
    level: 'Pro',
    name: 'CFOP',
    fullName: 'CFOP (phương pháp Fridrich)',
    formulas: 'Công thức nâng cao',
    summary:
        'Cross → F2L → OLL → PLL: phương pháp của hầu hết người giải nhanh. '
        'Khoảng 55–65 nước với 41 + 57 + 21 công thức.',
    stages: SolveStage.cfop,
  ),
  zb(
    level: 'Master',
    name: 'ZB',
    fullName: 'Phương pháp ZB (Zborowski–Bruchem)',
    formulas: 'Công thức ZB',
    summary:
        'Cross → F2L 3 cặp → ZBLS (cặp cuối + dấu cộng vàng) → ZBLL (cả tầng '
        'cuối trong 1 công thức). Khoảng 45–55 nước với 302 + 472 công thức, '
        'dành cho người đã thuộc CFOP.',
    stages: SolveStage.zb,
  );

  const SolveMethod({
    required this.level,
    required this.name,
    required this.fullName,
    required this.formulas,
    required this.summary,
    required this.stages,
  });

  /// Who it is for: "Newbie" or "Pro".
  final String level;
  final String name;
  final String fullName;

  /// What its formulas are called in the library.
  final String formulas;
  final String summary;
  final List<SolveStage> stages;
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

  /// The pieces this step works on (each given by its colors), to
  /// highlight them: one piece, or an F2L pair.
  final List<Set<Face>>? focus;

  @override
  String toString() => '[${stage.title}] ${Move.format(moves)} — $explanation';
}
