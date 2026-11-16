import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:sun_tracker/src/ar/sky_projection.dart';
import 'package:sun_tracker/src/math/vec3.dart';

void main() {
  /// A phone held upright in portrait, with the back camera facing north.
  const facingNorth = Matrix3(Vec3(1, 0, 0), Vec3(0, 0, -1), Vec3(0, 1, 0));

  SkyProjection projection({double northOffset = 0}) => SkyProjection(
    deviceToWorld: facingNorth,
    northOffset: northOffset,
    focalLength: 500,
    center: const Offset(200, 400),
  );

  test('projects the direction the camera faces onto the center', () {
    final point = projection().project(
      Vec3.fromHorizontal(azimuth: 0, altitude: 0),
    );
    expect(point!.dx, closeTo(200, 1e-9));
    expect(point.dy, closeTo(400, 1e-9));
  });

  test('projects east to the right and up to the top', () {
    final east = projection().project(
      Vec3.fromHorizontal(azimuth: 10 * math.pi / 180, altitude: 0),
    );
    final up = projection().project(
      Vec3.fromHorizontal(azimuth: 0, altitude: 10 * math.pi / 180),
    );
    expect(east!.dx, greaterThan(200));
    expect(up!.dy, lessThan(400));
    expect(east.dx - 200, closeTo(500 * math.tan(10 * math.pi / 180), 1e-6));
  });

  test('hides directions behind the camera', () {
    expect(
      projection().project(Vec3.fromHorizontal(azimuth: math.pi, altitude: 0)),
      isNull,
    );
  });

  test('applies the magnetic declination', () {
    final declination = 10 * math.pi / 180;
    final rotated = projection(northOffset: declination);
    final point = rotated.project(
      Vec3.fromHorizontal(azimuth: declination, altitude: 0),
    );
    expect(point!.dx, closeTo(200, 1e-9));
    expect(rotated.heading, closeTo(declination, 1e-9));
  });

  test('converts quaternions like Android does', () {
    final angle = math.pi / 2;
    final quaternion = Quaternion(
      math.cos(angle / 2),
      math.sin(angle / 2),
      0,
      0,
    );
    final matrix = quaternion.toMatrix();
    final world = matrix.transform(const Vec3(0, 0, -1));
    expect(world.x, closeTo(0, 1e-9));
    expect(world.y, closeTo(1, 1e-9));
    expect(world.z, closeTo(0, 1e-9));
  });
}
