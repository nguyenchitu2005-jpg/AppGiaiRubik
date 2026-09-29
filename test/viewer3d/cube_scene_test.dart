import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:rubik_solver/core/cube/cube_state.dart';
import 'package:rubik_solver/core/cube/face.dart';
import 'package:rubik_solver/core/cube/move.dart';
import 'package:rubik_solver/core/cube/scrambler.dart';
import 'package:rubik_solver/features/viewer3d/cube_scene.dart';
import 'package:vector_math/vector_math_64.dart' show Matrix3;

void main() {
  const size = Size(400, 400);
  final defaultView = CubeScene.defaultOrientation().asRotationMatrix();

  List<ScenePolygon> stickers(CubeState state, Matrix3 view, [LayerTurn? turn]) =>
      CubeScene.build(state: state, view: view, size: size, turn: turn)
          .where((p) => p.sticker != null)
          .toList();

  test('looking straight at F shows exactly the 9 front stickers', () {
    final visible = stickers(CubeState.solved(), Matrix3.identity());
    expect(visible, hasLength(9));
    expect(visible.map((p) => p.sticker).toSet(), {Face.f});
  });

  test('default view shows the U, F and R faces like the reference image', () {
    final visible = stickers(CubeState.solved(), defaultView);
    expect(visible, hasLength(27));
    expect(visible.map((p) => p.sticker).toSet(), {Face.u, Face.f, Face.r});
    for (final p in visible) {
      for (final point in p.points) {
        expect(size.contains(point), isTrue, reason: 'cube must fit the view');
      }
    }
  });

  test('U is lit brighter than the side faces', () {
    final visible = stickers(CubeState.solved(), defaultView);
    final top = visible.firstWhere((p) => p.sticker == Face.u).shade;
    final front = visible.firstWhere((p) => p.sticker == Face.f).shade;
    expect(top, greaterThan(front));
  });

  test('a full animated turn lands exactly on the engine result', () {
    final state = CubeState.solved().applyAll(Scrambler(math.Random(9)).generate());
    for (final layer in MoveLayer.values) {
      for (final turns in [1, 2, 3]) {
        final move = Move(layer, turns);
        final animated = stickers(state, defaultView, LayerTurn.forMove(move, 1));
        final expected = stickers(state.apply(move), defaultView);
        expect(animated, hasLength(expected.length), reason: move.notation);
        for (final p in expected) {
          final match = animated.where((a) =>
              a.sticker == p.sticker && (a.centroid - p.centroid).distance < 0.5);
          expect(match, isNotEmpty, reason: '${move.notation} at ${p.centroid}');
        }
      }
    }
  });

  test('mid-turn shows the black cut faces between slabs', () {
    final state = CubeState.solved();
    final idle = CubeScene.build(state: state, view: defaultView, size: size);
    final midTurn = CubeScene.build(
        state: state,
        view: defaultView,
        size: size,
        turn: LayerTurn.forMove(Move.parse('U'), 0.5));
    int bodies(List<ScenePolygon> ps) => ps.where((p) => p.sticker == null).length;
    expect(bodies(midTurn), greaterThan(bodies(idle)));
  });
}
