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
      MoveLayer.uw => '2 tầng trên (mặt trên và lát giữa)',
      MoveLayer.rw => '2 tầng phải (mặt phải và lát giữa)',
      MoveLayer.fw => '2 tầng trước (mặt trước và lát giữa)',
      MoveLayer.dw => '2 tầng dưới (mặt dưới và lát giữa)',
      MoveLayer.lw => '2 tầng trái (mặt trái và lát giữa)',
      MoveLayer.bw => '2 tầng sau (mặt sau và lát giữa)',
    };
    final how = switch (turns) {
      1 => 'theo chiều kim đồng hồ',
      3 => 'ngược chiều kim đồng hồ',
      _ => '2 lần (180°)',
    };
    return 'Xoay $what $how';
  }
}
