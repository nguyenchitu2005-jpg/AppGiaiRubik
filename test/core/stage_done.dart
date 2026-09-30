import 'package:rubik_solver/core/cube/cube_state.dart';
import 'package:rubik_solver/core/cube/cubie_cube.dart';
import 'package:rubik_solver/core/cube/face.dart';
import 'package:rubik_solver/core/cube/move.dart';
import 'package:rubik_solver/core/solver/solve_step.dart';

bool edgeOk(CubieCube c, Edge e) =>
    c.ep[e.index] == e.index && c.eo[e.index] == 0;
bool cornerOk(CubieCube c, Corner k) =>
    c.cp[k.index] == k.index && c.co[k.index] == 0;

/// What must hold once [stage] is finished (on the centre-normalised cube).
bool stageDone(SolveStage stage, CubeState physical) {
  final work = physical.withCentersNormalized();
  final c = CubieCube.fromState(work);
  final cross = [Edge.dr, Edge.df, Edge.dl, Edge.db].every((e) => edgeOk(c, e));
  final corners = [
    Corner.dfr,
    Corner.dlf,
    Corner.dbl,
    Corner.drb,
  ].every((k) => cornerOk(c, k));
  final middle = [
    Edge.fr,
    Edge.fl,
    Edge.bl,
    Edge.br,
  ].every((e) => edgeOk(c, e));
  return switch (stage) {
    SolveStage.hold => physical.center(Face.d) == Face.u,
    SolveStage.whiteCross => cross,
    SolveStage.whiteCorners => cross && corners,
    SolveStage.middleLayer => cross && corners && middle,
    SolveStage.yellowCross =>
      cross &&
          corners &&
          middle &&
          [1, 3, 5, 7].every((i) => work[i] == Face.u),
    SolveStage.yellowFace =>
      cross &&
          corners &&
          middle &&
          [for (var i = 0; i < 9; i++) i].every((i) => work[i] == Face.u),
    SolveStage.lastLayerCorners => [0, 1, 2, 3].any((u) {
      final turned = CubieCube.fromState(
        work.applyAll(u == 0 ? const <Move>[] : [Move(MoveLayer.u, u)]),
      );
      return [0, 1, 2, 3].every((k) => turned.cp[k] == k) &&
          [for (var i = 0; i < 9; i++) i].every((i) => work[i] == Face.u);
    }),
    SolveStage.lastLayerEdges => physical.isSolved,
    SolveStage.cross => cross,
    SolveStage.f2l => cross && corners && middle,
    SolveStage.oll =>
      cross &&
          corners &&
          middle &&
          [for (var i = 0; i < 9; i++) i].every((i) => work[i] == Face.u),
    SolveStage.pll => physical.isSolved,
    SolveStage.zbls =>
      cross &&
          corners &&
          middle &&
          [1, 3, 5, 7].every((i) => work[i] == Face.u),
    SolveStage.zbll => physical.isSolved,
    SolveStage.quick => false, // never produced by a human method
  };
}
