import 'move.dart';

extension MoveDescription on Move {
  /// Plain-language instruction, e.g. "Xoay mặt phải ngược chiều kim đồng hồ".
  String get description {
    final what = switch (layer) {
      MoveLayer.u => 'mặt trên',
      MoveLayer.d => 'mặt dưới',
      MoveLayer.f => 'mặt trước',
      MoveLayer.b => 'mặt sau',
      MoveLayer.l => 'mặt trái',
      MoveLayer.r => 'mặt phải',
      MoveLayer.m => 'lát giữa dọc (theo chiều mặt trái)',
      MoveLayer.e => 'lát giữa ngang (theo chiều mặt dưới)',
      MoveLayer.s => 'lát giữa đứng (theo chiều mặt trước)',
      MoveLayer.x => 'cả khối theo trục mặt phải',
      MoveLayer.y => 'cả khối theo trục mặt trên',
      MoveLayer.z => 'cả khối theo trục mặt trước',
    };
    final how = switch (turns) {
      1 => 'theo chiều kim đồng hồ',
      3 => 'ngược chiều kim đồng hồ',
      _ => '2 lần (180°)',
    };
    return 'Xoay $what $how';
  }
}
