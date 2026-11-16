import 'dart:math' as math;
import 'dart:ui';

import 'package:sun_tracker/src/math/vec3.dart';

/// Projects directions in the true North, East, Up frame onto the screen of a
/// portrait device whose back camera looks along the device's negative z axis.
class SkyProjection {
  SkyProjection({
    required this.deviceToWorld,
    required double northOffset,
    required this.focalLength,
    required this.center,
  }) : _cosOffset = math.cos(northOffset),
       _sinOffset = math.sin(northOffset);

  /// Points closer to the camera plane than this are clipped.
  static const nearPlane = 0.02;

  /// Maps device coordinates to the magnetic East, North, Up frame.
  final Matrix3 deviceToWorld;

  /// Focal length in logical pixels.
  final double focalLength;

  final Offset center;

  final double _cosOffset;
  final double _sinOffset;

  /// Returns camera coordinates (right, up, forward) for a true world
  /// direction.
  Vec3 toCamera(Vec3 world) {
    final magnetic = Vec3(
      world.x * _cosOffset - world.y * _sinOffset,
      world.y * _cosOffset + world.x * _sinOffset,
      world.z,
    );
    final device = deviceToWorld.transposeTransform(magnetic);
    return Vec3(device.x, device.y, -device.z);
  }

  /// Projects camera coordinates, which must be in front of the camera.
  Offset projectCamera(Vec3 camera) => Offset(
    center.dx + focalLength * camera.x / camera.z,
    center.dy - focalLength * camera.y / camera.z,
  );

  Offset? project(Vec3 world) {
    final camera = toCamera(world);
    return camera.z > nearPlane ? projectCamera(camera) : null;
  }

  /// The true azimuth in radians that the camera is pointing towards.
  double get heading {
    final forward = deviceToWorld.transform(const Vec3(0, 0, -1));
    final magneticHeading = math.atan2(forward.x, forward.y);
    final trueHeading = magneticHeading + math.atan2(_sinOffset, _cosOffset);
    final result = trueHeading % (2 * math.pi);
    return result < 0 ? result + 2 * math.pi : result;
  }

  /// The camera pitch in radians, positive when looking above the horizon.
  double get pitch {
    final forward = deviceToWorld.transform(const Vec3(0, 0, -1));
    return math.asin(forward.z.clamp(-1.0, 1.0));
  }

  /// Adds a polyline through world directions to [path], clipping the parts
  /// that are behind the camera.
  void addPolyline(Path path, Iterable<Vec3> worldPoints) {
    Vec3? previous;
    var penDown = false;
    for (final world in worldPoints) {
      final current = toCamera(world);
      if (previous == null) {
        if (current.z > nearPlane) {
          final point = projectCamera(current);
          path.moveTo(point.dx, point.dy);
          penDown = true;
        }
        previous = current;
        continue;
      }
      final previousVisible = previous.z > nearPlane;
      final currentVisible = current.z > nearPlane;
      if (previousVisible && currentVisible) {
        final point = projectCamera(current);
        if (!penDown) {
          final start = projectCamera(previous);
          path.moveTo(start.dx, start.dy);
        }
        path.lineTo(point.dx, point.dy);
        penDown = true;
      } else if (previousVisible != currentVisible) {
        final t = (nearPlane - previous.z) / (current.z - previous.z);
        final clipped = projectCamera(Vec3.lerp(previous, current, t));
        if (previousVisible) {
          if (!penDown) {
            final start = projectCamera(previous);
            path.moveTo(start.dx, start.dy);
          }
          path.lineTo(clipped.dx, clipped.dy);
          penDown = false;
        } else {
          final point = projectCamera(current);
          path.moveTo(clipped.dx, clipped.dy);
          path.lineTo(point.dx, point.dy);
          penDown = true;
        }
      } else {
        penDown = false;
      }
      previous = current;
    }
  }
}
