import '../algorithms.dart';
import '../solve_step.dart';
import 'f2l_cases.dart';

/// The algorithms of CFOP: 41 F2L (one per case of the front-right slot),
/// then 57 OLL and 21 PLL numbered and named as speed cubers know them
/// (speedsolving.com wiki).
abstract final class CfopAlgorithms {
  static final List<Algorithm> f2l = [
    for (final (i, c) in f2lCases.indexed)
      Algorithm(
        name: 'F2L ${i + 1}',
        notation: c.notation,
        stage: SolveStage.f2l,
        group: c.category.label,
        usage:
            '${c.category.label}. Cặp góc–cạnh của khe trước–phải: xoay '
            'mặt trên (U) cho khớp hình rồi làm công thức để ghép cặp và đưa '
            'vào khe.',
      ),
  ];

  static final List<Algorithm> oll = [
    for (final (n, group, notation, nickname) in _oll)
      Algorithm(
        name: nickname == null ? 'OLL $n' : 'OLL $n · $nickname',
        notation: notation,
        stage: SolveStage.oll,
        group: group,
        usage:
            'Nhóm $group: ${_ollGroupHints[group]}. Xoay mặt trên (U) cho '
            'khớp hình rồi làm công thức, cả mặt trên sẽ vàng.',
      ),
  ];

  static final List<Algorithm> pll = [
    for (final (name, group, notation) in _pll)
      Algorithm(
        name: '$name-perm',
        notation: notation,
        stage: SolveStage.pll,
        group: group,
        usage:
            'Nhóm $group: ${_pllGroupHints[group]}. Xoay mặt trên (U) cho '
            'khớp hình rồi làm công thức; cuối cùng xoay U cho khớp màu.',
      ),
  ];

  static const _ollGroupHints = {
    'Chấm': 'không cạnh vàng nào hướng lên, chỉ có tâm vàng',
    'Chữ I': 'hai cạnh vàng đối nhau tạo đường thẳng qua tâm',
    'Dấu cộng': 'cả 4 cạnh đã vàng, chỉ còn các góc',
    'Góc đã vàng': 'cả 4 góc đã vàng, chỉ còn các cạnh',
    'Hình vuông': 'hai cạnh vàng kề nhau cùng một góc tạo ô vuông 2×2',
    'Tia chớp nhỏ': 'hai cạnh vàng kề nhau, hình tia chớp nhỏ',
    'Tia chớp lớn': 'hai cạnh vàng đối nhau, hình tia chớp lớn',
    'Con cá': 'hai cạnh vàng kề nhau, hình con cá',
    'Nước mã': 'hai cạnh vàng đối nhau, hình nước đi của quân mã',
    'Hình lệch': 'hai cạnh vàng kề nhau, hình không đối xứng',
    'Chữ P': 'hai cạnh vàng kề nhau, hình chữ P',
    'Chữ T': 'hai cạnh vàng đối nhau, hình chữ T',
    'Chữ C': 'hai cạnh vàng đối nhau, hình chữ C',
    'Chữ W': 'hai cạnh vàng kề nhau, hình chữ W (bậc thang)',
    'Chữ L': 'hai cạnh vàng kề nhau, hình chữ L lớn',
  };

  static const _pllGroupHints = {
    'Chỉ đổi cạnh': 'các góc đã đúng chỗ, chỉ các cạnh đổi chỗ',
    'Chỉ đổi góc': 'các cạnh đã đúng chỗ, chỉ các góc đổi chỗ',
    'Đổi 2 góc kề': 'có một mặt bên với 2 góc cùng màu (đèn pha)',
    'Đổi 2 góc chéo': 'không mặt bên nào có 2 góc cùng màu',
  };

  static const _oll = <(int, String, String, String?)>[
    (1, 'Chấm', "R U2 R2 F R F' U2 R' F R F'", null),
    (2, 'Chấm', "R U' R2 D' r U r' D R2 U R'", null),
    (3, 'Chấm', "f R U R' U' f' U' F R U R' U' F'", null),
    (4, 'Chấm', "f R U R' U' f' U F R U R' U' F'", null),
    (5, 'Hình vuông', "l' U2 L U L' U l", null),
    (6, 'Hình vuông', "r U2 R' U' R U' r'", null),
    (7, 'Tia chớp nhỏ', "r U R' U R U2 r'", null),
    (8, 'Tia chớp nhỏ', "l' U' L U' L' U2 l", null),
    (9, 'Con cá', "R U R' U' R' F R2 U R' U' F'", null),
    (10, 'Con cá', "R U R' U R' F R F' R U2 R'", null),
    (11, 'Tia chớp nhỏ', "r' R2 U R' U R U2 R' U M'", null),
    (12, 'Tia chớp nhỏ', "r R2 U' R U' R' U2 R U' r' R", null),
    (13, 'Nước mã', "F U R U2 R' U' R U R' F'", null),
    (14, 'Nước mã', "R' F R U R' F' R F U' F'", null),
    (15, 'Nước mã', "l' U' l L' U' L U l' U l", null),
    (16, 'Nước mã', "r U r' R U R' U' r U' r'", null),
    (17, 'Chấm', "R U R' U R' F R F' U2 R' F R F'", null),
    (18, 'Chấm', "R U2 R2 F R F' U2 M' U R U' r'", null),
    (19, 'Chấm', "S' R U R' S U' R' F R F'", null),
    (20, 'Chấm', "r' R U R U R' U' r R' M' U R U' r'", null),
    (21, 'Dấu cộng', "R U R' U R U' R' U R U2 R'", 'H'),
    (22, 'Dấu cộng', "R U2 R2 U' R2 U' R2 U2 R", 'Pi'),
    (23, 'Dấu cộng', "R2 D' R U2 R' D R U2 R", 'Đèn pha'),
    (24, 'Dấu cộng', "r U R' U' r' F R F'", 'Chameleon'),
    (25, 'Dấu cộng', "F R' F' r U R U' r'", 'Bowtie'),
    (26, 'Dấu cộng', "R U2 R' U' R U' R'", 'Anti-Sune'),
    (27, 'Dấu cộng', "R U R' U R U2 R'", 'Sune'),
    (28, 'Góc đã vàng', "r U R' U' r' R U R U' R'", null),
    (29, 'Hình lệch', "R U R' U' R U' R' F' U' F R U R'", null),
    (30, 'Hình lệch', "F U R U2 R' U' R U2 R' U' F'", null),
    (31, 'Chữ P', "R' U' F U R U' R' F' R", null),
    (32, 'Chữ P', "S R U R' U' R' F R f'", null),
    (33, 'Chữ T', "R U R' U' R' F R F'", null),
    (34, 'Chữ C', "R U R2 U' R' F R U R U' F'", null),
    (35, 'Con cá', "R U2 R2 F R F' R U2 R'", null),
    (36, 'Chữ W', "L' U' L U' L' U L U L F' L' F", null),
    (37, 'Con cá', "F R' F' R U R U' R'", null),
    (38, 'Chữ W', "R U R' U R U' R' U' R' F R F'", null),
    (39, 'Tia chớp lớn', "L F' L' U' L U F U' L'", null),
    (40, 'Tia chớp lớn', "R' F R U R' U' F' U R", null),
    (41, 'Hình lệch', "R U R' U R U2 R' F R U R' U' F'", null),
    (42, 'Hình lệch', "R' U' R U' R' U2 R F R U R' U' F'", null),
    (43, 'Chữ P', "R' U' F' U F R", null),
    (44, 'Chữ P', "F U R U' R' F'", null),
    (45, 'Chữ T', "F R U R' U' F'", null),
    (46, 'Chữ C', "R' U' R' F R F' U R", null),
    (47, 'Chữ L', "F R' F' R U2 R U' R' U R U2 R'", null),
    (48, 'Chữ L', "F R U R' U' R U R' U' F'", null),
    (49, 'Chữ L', "r U' r2 U r2 U r2 U' r", null),
    (50, 'Chữ L', "R' F R2 B' R2 F' R2 B R'", null),
    (51, 'Chữ I', "F U R U' R' U R U' R' F'", null),
    (52, 'Chữ I', "R U R' U R U' B U' B' R'", null),
    (53, 'Chữ L', "l' U' L U' L' U L U' L' U2 l", null),
    (54, 'Chữ L', "r U R' U R U' R' U R U2 r'", null),
    (55, 'Chữ I', "R' F R U R U' R2 F' R2 U' R' U R U R'", null),
    (56, 'Chữ I', "r U r' U R U' R' U R U' R' r U' r'", null),
    (57, 'Góc đã vàng', "R U R' U' M' U R U' r'", null),
  ];

  static const _pll = <(String, String, String)>[
    ('Ua', 'Chỉ đổi cạnh', "R U' R U R U R U' R' U' R2"),
    ('Ub', 'Chỉ đổi cạnh', "R2 U R U R' U' R' U' R' U R'"),
    ('H', 'Chỉ đổi cạnh', 'M2 U M2 U2 M2 U M2'),
    ('Z', 'Chỉ đổi cạnh', "M' U M2 U M2 U M' U2 M2"),
    ('Aa', 'Chỉ đổi góc', "x R' U R' D2 R U' R' D2 R2 x'"),
    ('Ab', 'Chỉ đổi góc', "x R2 D2 R U R' D2 R U' R x'"),
    ('E', 'Chỉ đổi góc', "x' R U' R' D R U R' D' R U R' D R U' R' D' x"),
    ('T', 'Đổi 2 góc kề', "R U R' U' R' F R2 U' R' U' R U R' F'"),
    ('F', 'Đổi 2 góc kề', "R' U' F' R U R' U' R' F R2 U' R' U' R U R' U R"),
    ('Ja', 'Đổi 2 góc kề', "x R2 F R F' R U2 r' U r U2 x'"),
    ('Jb', 'Đổi 2 góc kề', "R U R' F' R U R' U' R' F R2 U' R'"),
    ('Ra', 'Đổi 2 góc kề', "R U' R' U' R U R D R' U' R D' R' U2 R'"),
    ('Rb', 'Đổi 2 góc kề', "R2 F R U R U' R' F' R U2 R' U2 R"),
    ('Ga', 'Đổi 2 góc kề', "R2 U R' U R' U' R U' R2 U' D R' U R D'"),
    ('Gb', 'Đổi 2 góc kề', "R' U' R U D' R2 U R' U R U' R U' R2 D"),
    ('Gc', 'Đổi 2 góc kề', "R2 U' R U' R U R' U R2 U D' R U' R' D"),
    ('Gd', 'Đổi 2 góc kề', "R U R' U' D R2 U' R U' R' U R' U R2 D'"),
    ('V', 'Đổi 2 góc chéo', "R U' R U R' D R D' R U' D R2 U R2 D' R2"),
    ('Y', 'Đổi 2 góc chéo', "F R U' R' U' R U R' F' R U R' U' R' F R F'"),
    (
      'Na',
      'Đổi 2 góc chéo',
      "R U R' U R U R' F' R U R' U' R' F R2 U' R' U2 R U' R'",
    ),
    ('Nb', 'Đổi 2 góc chéo', "R' U R U' R' F' U' F R U R' F R' F' R U' R"),
  ];
}
