import 'dart:math' as math;
import 'dart:ui';

import 'package:vector_math/vector_math_64.dart';

import '../../core/cube/cube_state.dart';
import '../../core/cube/face.dart';
import '../../core/cube/move.dart';

/// A layer caught part-way through a turn.
class LayerTurn {
  const LayerTurn(this.layer, this.angle);

  /// [move] turned by [progress] (0 → 1) of its full angle.
  factory LayerTurn.forMove(Move move, double progress) => LayerTurn(
    move.layer,
    (move.isPrime ? -1 : move.turns) * math.pi / 2 * progress,
  );

  final MoveLayer layer;

  /// Radians, positive = clockwise as seen from [MoveLayer.face].
  final double angle;

  @override
  bool operator ==(Object other) =>
      other is LayerTurn && other.layer == layer && other.angle == angle;

  @override
  int get hashCode => Object.hash(layer, angle);
}

/// Where to print a face's name: an affine frame lying on the face's center
/// sticker, oriented like the unfolded net (so text is never mirrored).
class FaceLabel {
  const FaceLabel({
    required this.face,
    required this.origin,
    required this.right,
    required this.down,
  });

  /// The face position this label names (U = whatever is on top now).
  final Face face;

  /// Projected center of the center sticker.
  final Offset origin;

  /// Screen vector for one cubie-width towards the face's right.
  final Offset right;

  /// Screen vector for one cubie-width towards the face's bottom.
  final Offset down;

  /// The same frame turned in the face plane by a multiple of 90° so its
  /// text reads upright on screen. Turning (never flipping) keeps the text
  /// from being mirrored.
  FaceLabel get upright {
    var best = this;
    var r = right, d = down;
    for (var i = 0; i < 3; i++) {
      (r, d) = (d, -r);
      if (d.dy / d.distance > best.down.dy / best.down.distance) {
        best = FaceLabel(face: face, origin: origin, right: r, down: d);
      }
    }
    return best;
  }
}

/// A projected polygon ready to be filled, in back-to-front order.
class ScenePolygon {
  const ScenePolygon({
    required this.points,
    required this.shade,
    this.sticker,
    this.faceletIndex,
    this.label,
  });

  final List<Offset> points;

  /// Diffuse light in [0, 1]: 0 = facing away from the light, 1 = facing it.
  final double shade;

  /// Sticker color, or null for the black plastic body.
  final Face? sticker;

  final int? faceletIndex;

  /// Set on center stickers: where to print the face name.
  final FaceLabel? label;

  Offset get centroid {
    var sum = Offset.zero;
    for (final p in points) {
      sum += p;
    }
    return sum / points.length.toDouble();
  }
}

/// Turns a [CubeState] into 2D polygons with perspective projection.
///
/// Cubies are grouped into convex slabs (one group when idle, three slabs
/// along the turning axis mid-turn). Within a convex slab, back-face culling
/// alone gives correct visibility; slabs are drawn farthest first.
abstract final class CubeScene {
  static const double cameraDistance = 12;

  static Quaternion defaultOrientation() =>
      Quaternion.axisAngle(Vector3(1, 0, 0), 0.45) *
      Quaternion.axisAngle(Vector3(0, 1, 0), -0.6);

  static final Vector3 _light = Vector3(-0.25, 0.7, 0.75)..normalize();

  /// Radius of the cube's bounding sphere, magnified by perspective.
  static final double _fitRadius = () {
    final r = 1.5 * math.sqrt(3);
    return r * cameraDistance / (cameraDistance - r);
  }();

  static const double _stickerHalf = 0.44;
  static const double _stickerRadius = 0.13;

  /// Rounded-square outline in a face's local (u, v) coordinates.
  static final List<(double, double)> _stickerOutline = () {
    const inner = _stickerHalf - _stickerRadius;
    const steps = 5;
    final points = <(double, double)>[];
    for (final (cx, cy, start) in const [
      (inner, inner, 0.0),
      (-inner, inner, math.pi / 2),
      (-inner, -inner, math.pi),
      (inner, -inner, 3 * math.pi / 2),
    ]) {
      for (var i = 0; i <= steps; i++) {
        final a = start + math.pi / 2 * i / steps;
        points.add((
          cx + _stickerRadius * math.cos(a),
          cy + _stickerRadius * math.sin(a),
        ));
      }
    }
    return points;
  }();

  /// (right, up) directions of each face as drawn in the unfolded net.
  static final Map<Face, (IVec3, IVec3)> _faceAxes = {
    for (final face in Face.values)
      face: (
        FaceletGeometry.position(face.offset + 5) -
            FaceletGeometry.position(face.offset + 4),
        FaceletGeometry.position(face.offset + 1) -
            FaceletGeometry.position(face.offset + 4),
      ),
  };

  static final List<IVec3> _cubies = [
    for (var x = -1; x <= 1; x++)
      for (var y = -1; y <= 1; y++)
        for (var z = -1; z <= 1; z++) IVec3(x, y, z),
  ];

  static List<ScenePolygon> build({
    required CubeState state,
    required Matrix3 view,
    required Size size,
    LayerTurn? turn,
  }) {
    final scale = size.shortestSide / 2 / _fitRadius;
    final origin = size.center(Offset.zero);
    final camera = Vector3(0, 0, cameraDistance);

    Offset project(Vector3 p) {
      final f = cameraDistance / (cameraDistance - p.z) * scale;
      return Offset(origin.dx + p.x * f, origin.dy - p.y * f);
    }

    final polygons = <ScenePolygon>[];
    for (final group in _groups(view, turn)) {
      final transform = view.multiplied(group.rotation);
      final members = group.cubies.toSet();
      for (final cubie in group.cubies) {
        for (final face in Face.values) {
          final n = face.normal;
          if (members.contains(cubie + n)) continue; // hidden inside the slab

          final normal = transform.transformed(_vec(n));
          final center = transform.transformed(_vec(cubie) + _vec(n) * 0.5);
          if ((camera - center).dot(normal) <= 0) continue; // back face

          final (u, v) = _tangents(n);
          final tu = transform.transformed(_vec(u));
          final tv = transform.transformed(_vec(v));
          final shade = math.max(0.0, normal.dot(_light));

          polygons.add(
            ScenePolygon(
              points: [
                for (final (s, t) in const [
                  (0.5, 0.5),
                  (-0.5, 0.5),
                  (-0.5, -0.5),
                  (0.5, -0.5),
                ])
                  project(center + tu * s + tv * t),
              ],
              shade: shade,
            ),
          );

          if (cubie.dot(n) == 1) {
            final index = FaceletGeometry.indexOf(cubie, n);
            polygons.add(
              ScenePolygon(
                points: [
                  for (final (s, t) in _stickerOutline)
                    project(center + tu * s + tv * t),
                ],
                shade: shade,
                sticker: state[index],
                faceletIndex: index,
                label: index % 9 == 4
                    ? _label(
                        Face.values[index ~/ 9],
                        center,
                        transform,
                        project,
                      )
                    : null,
              ),
            );
          }
        }
      }
    }
    return polygons;
  }

  static FaceLabel _label(
    Face face,
    Vector3 center,
    Matrix3 transform,
    Offset Function(Vector3) project,
  ) {
    final (right, up) = _faceAxes[face]!;
    final origin = project(center);
    return FaceLabel(
      face: face,
      origin: origin,
      right: project(center + transform.transformed(_vec(right))) - origin,
      down: project(center - transform.transformed(_vec(up))) - origin,
    );
  }

  /// Facelet index of the topmost sticker under [point], or null if the
  /// point hits the black body or misses the cube.
  static int? stickerAt(List<ScenePolygon> polygons, Offset point) {
    for (final polygon in polygons.reversed) {
      if (_polygonContains(polygon.points, point)) return polygon.faceletIndex;
    }
    return null;
  }

  static bool _polygonContains(List<Offset> points, Offset p) {
    var inside = false;
    for (var i = 0, j = points.length - 1; i < points.length; j = i++) {
      final a = points[i], b = points[j];
      if ((a.dy > p.dy) != (b.dy > p.dy) &&
          p.dx < (b.dx - a.dx) * (p.dy - a.dy) / (b.dy - a.dy) + a.dx) {
        inside = !inside;
      }
    }
    return inside;
  }

  static List<_Group> _groups(Matrix3 view, LayerTurn? turn) {
    if (turn == null) return [_Group(_cubies, Matrix3.identity())];

    final axis = turn.layer.face.normal;
    final rotation = Quaternion.axisAngle(
      _vec(axis),
      -turn.angle,
    ).asRotationMatrix();
    // Camera position along the turning axis, in cube coordinates.
    final cameraOnAxis = view
        .transposed()
        .transformed(Vector3(0, 0, cameraDistance))
        .dot(_vec(axis));

    final slabs =
        [
          for (var k = -1; k <= 1; k++)
            (
              k,
              [
                for (final c in _cubies)
                  if (c.dot(axis) == k) c,
              ],
            ),
        ]..sort(
          (a, b) => (b.$1 - cameraOnAxis).abs().compareTo(
            (a.$1 - cameraOnAxis).abs(),
          ),
        );

    return [
      for (final (_, cubies) in slabs)
        _Group(
          cubies,
          turn.layer.contains(cubies.first) ? rotation : Matrix3.identity(),
        ),
    ];
  }

  static (IVec3, IVec3) _tangents(IVec3 n) {
    if (n.x != 0) return (const IVec3(0, 1, 0), const IVec3(0, 0, 1));
    if (n.y != 0) return (const IVec3(1, 0, 0), const IVec3(0, 0, 1));
    return (const IVec3(1, 0, 0), const IVec3(0, 1, 0));
  }

  static Vector3 _vec(IVec3 v) =>
      Vector3(v.x.toDouble(), v.y.toDouble(), v.z.toDouble());
}

class _Group {
  const _Group(this.cubies, this.rotation);

  final List<IVec3> cubies;
  final Matrix3 rotation;
}
