import 'dart:math' as math;

class Vec3 {
  const Vec3(this.x, this.y, this.z);

  /// A unit vector in the local East, North, Up frame for the given horizontal
  /// coordinates, where [azimuth] is measured clockwise from north.
  factory Vec3.fromHorizontal({
    required double azimuth,
    required double altitude,
  }) {
    final cosAltitude = math.cos(altitude);
    return Vec3(
      math.sin(azimuth) * cosAltitude,
      math.cos(azimuth) * cosAltitude,
      math.sin(altitude),
    );
  }

  final double x;
  final double y;
  final double z;

  Vec3 operator +(Vec3 other) => Vec3(x + other.x, y + other.y, z + other.z);
  Vec3 operator -(Vec3 other) => Vec3(x - other.x, y - other.y, z - other.z);
  Vec3 operator *(double factor) => Vec3(x * factor, y * factor, z * factor);

  double dot(Vec3 other) => x * other.x + y * other.y + z * other.z;

  Vec3 cross(Vec3 other) => Vec3(
    y * other.z - z * other.y,
    z * other.x - x * other.z,
    x * other.y - y * other.x,
  );

  double get length => math.sqrt(x * x + y * y + z * z);

  Vec3 normalized() {
    final l = length;
    return l == 0 ? this : this * (1 / l);
  }

  static Vec3 lerp(Vec3 a, Vec3 b, double t) => a + (b - a) * t;
}

/// A unit quaternion in (w, x, y, z) order.
class Quaternion {
  const Quaternion(this.w, this.x, this.y, this.z);

  static const identity = Quaternion(1, 0, 0, 0);

  final double w;
  final double x;
  final double y;
  final double z;

  Quaternion normalized() {
    final l = math.sqrt(w * w + x * x + y * y + z * z);
    return l == 0 ? identity : Quaternion(w / l, x / l, y / l, z / l);
  }

  /// Normalized linear interpolation along the shortest arc.
  Quaternion nlerp(Quaternion target, double t) {
    final sign = (w * target.w + x * target.x + y * target.y + z * target.z) < 0
        ? -1.0
        : 1.0;
    return Quaternion(
      w + (target.w * sign - w) * t,
      x + (target.x * sign - x) * t,
      y + (target.y * sign - y) * t,
      z + (target.z * sign - z) * t,
    ).normalized();
  }

  /// The row major rotation matrix that maps device coordinates to world
  /// coordinates, matching Android's `SensorManager.getRotationMatrixFromVector`.
  Matrix3 toMatrix() {
    final xx = 2 * x * x;
    final yy = 2 * y * y;
    final zz = 2 * z * z;
    final xy = 2 * x * y;
    final xz = 2 * x * z;
    final yz = 2 * y * z;
    final wx = 2 * w * x;
    final wy = 2 * w * y;
    final wz = 2 * w * z;
    return Matrix3(
      Vec3(1 - yy - zz, xy - wz, xz + wy),
      Vec3(xy + wz, 1 - xx - zz, yz - wx),
      Vec3(xz - wy, yz + wx, 1 - xx - yy),
    );
  }
}

/// A 3x3 matrix stored as rows.
class Matrix3 {
  const Matrix3(this.row0, this.row1, this.row2);

  static const identity = Matrix3(Vec3(1, 0, 0), Vec3(0, 1, 0), Vec3(0, 0, 1));

  final Vec3 row0;
  final Vec3 row1;
  final Vec3 row2;

  Vec3 transform(Vec3 v) => Vec3(row0.dot(v), row1.dot(v), row2.dot(v));

  /// Multiplies the transpose of this matrix with [v].
  Vec3 transposeTransform(Vec3 v) => row0 * v.x + row1 * v.y + row2 * v.z;
}
