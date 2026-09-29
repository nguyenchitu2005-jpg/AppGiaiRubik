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

  test('hint arrows point the way the stickers move', () {
    final state = CubeState.solved();
    for (final layer in MoveLayer.values) {
      for (final turns in [1, 3]) {
        final move = Move(layer, turns);
        final arrows = CubeScene.hintArrows(
          move: move,
          view: defaultView,
          size: size,
        );
        expect(arrows, isNotEmpty, reason: move.notation);

        final before = stickers(state, defaultView, LayerTurn.forMove(move, 0));
        final after = stickers(
          state,
          defaultView,
          LayerTurn.forMove(move, 0.05),
        );
        for (final arrow in arrows) {
          final points = arrow.points;
          final mid = points.length ~/ 2;
          final at = points.length == 2
              ? (points[0] + points[1]) / 2
              : points[mid];
          final direction = points.length == 2
              ? points[1] - points[0]
              : points[mid + 1] - points[mid - 1];
          final nearest = before.reduce(
            (a, b) =>
                (a.centroid - at).distance < (b.centroid - at).distance ? a : b,
          );
          final moved = after.firstWhere(
            (p) => p.faceletIndex == nearest.faceletIndex,
          );
          final motion = moved.centroid - nearest.centroid;
          expect(
            motion.dx * direction.dx + motion.dy * direction.dy,
            greaterThan(0),
            reason: '${move.notation}: arrow at $at',
          );
        }
      }
    }
  });

  test('half turns get double-headed arrows', () {
    final arrows = CubeScene.hintArrows(
      move: Move.parse('R2'),
      view: defaultView,
      size: size,
    );
    expect(arrows.every((a) => a.doubleTurn), isTrue);
  });

  group('snapOrientation', () {
    final tilt = CubeScene.defaultOrientation().asRotationMatrix();

    /// The pose relative to the default tilt, which must be a signed
    /// permutation (one of the 24 ways to hold the cube).
    Matrix3 relativeTo(Quaternion q) =>
        tilt.transposed().multiplied(q.asRotationMatrix());

    bool isUpright(Quaternion q) {
      final m = relativeTo(q);
      for (var row = 0; row < 3; row++) {
        for (var col = 0; col < 3; col++) {
          final v = m.entry(row, col).abs();
          if (v > 1e-9 && (v - 1).abs() > 1e-9) return false;
        }
      }
      return true;
    }

    Quaternion turned(Quaternion q, Vector3 axis, double angle) =>
        Quaternion.axisAngle(axis, angle) * q;

    test('small drags settle back to the same pose', () {
      final start = CubeScene.defaultOrientation();
      final snapped = CubeScene.snapOrientation(
        turned(start, Vector3(0.3, 1, 0.2)..normalize(), 0.5),
      );
      expect(maxDiff(relativeTo(snapped), Matrix3.identity()), lessThan(1e-9));
    });

    test('turning past halfway brings the next face to the front', () {
      final start = CubeScene.defaultOrientation();
      final snapped = CubeScene.snapOrientation(
        turned(start, Vector3(0, 1, 0), math.pi / 2 + 0.3),
      );
      expect(isUpright(snapped), isTrue);
      // The left face now faces where the front face used to.
      final m = relativeTo(snapped);
      expect(m.transformed(Vector3(-1, 0, 0)).z, closeTo(1, 1e-9));
    });

    test('always lands on one of the 24 upright poses, showing 3 faces', () {
      final random = math.Random(12);
      final poses = <String>{};
      for (var n = 0; n < 500; n++) {
        final q = Quaternion.axisAngle(
          Vector3(
            random.nextDouble() - 0.5,
            random.nextDouble() - 0.5,
            random.nextDouble() - 0.5,
          )..normalize(),
          random.nextDouble() * 2 * math.pi,
        );
        final snapped = CubeScene.snapOrientation(q);
        expect(isUpright(snapped), isTrue);
        final again = CubeScene.snapOrientation(snapped);
        expect(maxDiff(relativeTo(again), relativeTo(snapped)), lessThan(1e-9));
        poses.add(relativeTo(snapped).storage.map((v) => v.round()).join(','));
        final visible = stickers(
          CubeState.solved(),
          snapped.asRotationMatrix(),
        );
        expect(visible, hasLength(27));
      }
      expect(poses, hasLength(24));
    });
  });
}

/// Largest entry-wise difference (vector_math's absoluteError only compares
/// matrix norms, which are equal for all rotations).
double maxDiff(Matrix3 a, Matrix3 b) {
  var result = 0.0;
  for (var i = 0; i < 9; i++) {
    result = math.max(result, (a.storage[i] - b.storage[i]).abs());
  }
  return result;
}
