import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:rubik_solver/core/cube/cube_state.dart';
import 'package:rubik_solver/core/cube/face.dart';
import 'package:rubik_solver/core/cube/move.dart';
import 'package:rubik_solver/core/cube/scrambler.dart';
import 'package:rubik_solver/features/viewer3d/cube_scene.dart';
import 'package:vector_math/vector_math_64.dart'
    show Matrix3, Quaternion, Vector3;

void main() {
  const size = Size(400, 400);
  final defaultView = CubeScene.defaultOrientation().asRotationMatrix();

  List<ScenePolygon> stickers(
    CubeState state,
    Matrix3 view, [
    LayerTurn? turn,
  ]) => CubeScene.build(
    state: state,
    view: view,
    size: size,
    turn: turn,
  ).where((p) => p.sticker != null).toList();

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
    final state = CubeState.solved().applyAll(
      Scrambler(math.Random(9)).generate(),
    );
    for (final layer in MoveLayer.values) {
      for (final turns in [1, 2, 3]) {
        final move = Move(layer, turns);
        final animated = stickers(
          state,
          defaultView,
          LayerTurn.forMove(move, 1),
        );
        final expected = stickers(state.apply(move), defaultView);
        expect(animated, hasLength(expected.length), reason: move.notation);
        for (final p in expected) {
          final match = animated.where(
            (a) =>
                a.sticker == p.sticker &&
                (a.centroid - p.centroid).distance < 0.5,
          );
          expect(
            match,
            isNotEmpty,
            reason: '${move.notation} at ${p.centroid}',
          );
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
      turn: LayerTurn.forMove(Move.parse('U'), 0.5),
    );
    int bodies(List<ScenePolygon> ps) =>
        ps.where((p) => p.sticker == null).length;
    expect(bodies(midTurn), greaterThan(bodies(idle)));
  });

  test('stickerAt finds the tapped sticker and ignores the body', () {
    final state = CubeState.solved();
    final front = CubeScene.build(
      state: state,
      view: Matrix3.identity(),
      size: size,
    );
    expect(CubeScene.stickerAt(front, size.center(Offset.zero)), 22); // F5
    expect(CubeScene.stickerAt(front, const Offset(2, 2)), isNull);

    final angled = CubeScene.build(state: state, view: defaultView, size: size);
    for (final p in angled.where((p) => p.sticker != null)) {
      expect(CubeScene.stickerAt(angled, p.centroid), p.faceletIndex);
    }
  });

  test('face labels sit on the visible centers', () {
    final labels = [
      for (final p in CubeScene.build(
        state: CubeState.solved(),
        view: defaultView,
        size: size,
      ))
        if (p.label != null) (p.faceletIndex!, p.label!.face),
    ];
    expect(labels, unorderedEquals([(4, Face.u), (22, Face.f), (13, Face.r)]));
  });

  test('face labels are never mirrored and read upright from any angle', () {
    final random = math.Random(8);
    for (var n = 0; n < 300; n++) {
      final view = Quaternion.axisAngle(
        Vector3(
          random.nextDouble() - 0.5,
          random.nextDouble() - 0.5,
          random.nextDouble() - 0.5,
        )..normalize(),
        random.nextDouble() * 2 * math.pi,
      ).asRotationMatrix();
      final polygons = CubeScene.build(
        state: CubeState.solved(),
        view: view,
        size: size,
      );
      for (final label in polygons.map((p) => p.label).nonNulls) {
        double det(FaceLabel l) =>
            l.right.dx * l.down.dy - l.right.dy * l.down.dx;
        expect(det(label), greaterThan(0), reason: 'mirrored ${label.face}');
        final upright = label.upright;
        expect(det(upright), closeTo(det(label), 1e-6));
        expect(upright.down.dy, greaterThan(0), reason: '${label.face}');
      }
    }
  });
}
