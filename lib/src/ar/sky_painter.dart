import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';
import 'package:sun_tracker/src/ar/sky_projection.dart';
import 'package:sun_tracker/src/ar/sun_scene.dart';
import 'package:sun_tracker/src/astronomy/sun_calculator.dart';
import 'package:sun_tracker/src/math/vec3.dart';
import 'package:sun_tracker/src/sensors/device_orientation_source.dart';
import 'package:sun_tracker/src/ui/formatting.dart';

const double _degrees = math.pi / 180;

const _pathColor = Color(0xFFF5C542);
const _markerColor = Color(0xFFFF9F43);
const _sunriseColor = Color(0xFFFF7EB3);
const _pillColor = Color(0xD91C1B22);

class SkyPainter extends CustomPainter {
  SkyPainter({
    required this.orientation,
    required this.northOffset,
    required this.focalLength,
    required this.scene,
    required this.selected,
    required this.overlayInsets,
  }) : super(repaint: orientation);

  final DeviceOrientationSource orientation;

  /// Radians between true north and magnetic north, including the manual
  /// heading correction.
  final double northOffset;

  /// Logical pixels.
  final double focalLength;

  final SunScene? scene;
  final SunPosition? selected;

  /// Screen areas covered by other widgets, used to keep the off screen sun
  /// indicator visible.
  final EdgeInsets overlayInsets;

  static final List<List<Vec3>> _meridians = [
    for (var azimuth = 0; azimuth < 360; azimuth += 15)
      [
        for (var altitude = -90; altitude <= 90; altitude += 3)
          Vec3.fromHorizontal(
            azimuth: azimuth * _degrees,
            altitude: altitude * _degrees,
          ),
      ],
  ];

  static final Map<int, List<Vec3>> _parallels = {
    for (var altitude = -60; altitude <= 75; altitude += 15)
      altitude: [
        for (var azimuth = 0; azimuth <= 360; azimuth += 2)
          Vec3.fromHorizontal(
            azimuth: azimuth * _degrees,
            altitude: altitude * _degrees,
          ),
      ],
  };

  static const _compassLabels = ['N', 'NE', 'E', 'SE', 'S', 'SW', 'W', 'NW'];

  static final Map<String, TextPainter> _textCache = {};

  @override
  void paint(Canvas canvas, Size size) {
    if (!orientation.hasData) {
      return;
    }
    final projection = SkyProjection(
      deviceToWorld: orientation.deviceToWorld,
      northOffset: northOffset,
      focalLength: focalLength,
      center: size.center(Offset.zero),
    );
    final bounds = Offset.zero & size;

    _paintGrid(canvas, projection);
    _paintCompass(canvas, projection, bounds);
    final scene = this.scene;
    if (scene != null) {
      _paintPath(canvas, projection, scene);
      _paintHourMarkers(canvas, projection, scene, bounds);
      _paintSunEvents(canvas, projection, scene, bounds);
    }
    final selected = this.selected;
    if (selected != null) {
      _paintSun(canvas, projection, selected, bounds);
    }
  }

  void _paintGrid(Canvas canvas, SkyProjection projection) {
    final gridPath = Path();
    for (final meridian in _meridians) {
      projection.addPolyline(gridPath, meridian);
    }
    for (final entry in _parallels.entries) {
      if (entry.key != 0) {
        projection.addPolyline(gridPath, entry.value);
      }
    }
    canvas.drawPath(
      gridPath,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.8
        ..color = Colors.white.withValues(alpha: 0.28),
    );

    final horizon = Path();
    projection.addPolyline(horizon, _parallels[0]!);
    canvas.drawPath(
      horizon,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4
        ..color = Colors.black.withValues(alpha: 0.2),
    );
    canvas.drawPath(
      horizon,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6
        ..color = Colors.white.withValues(alpha: 0.9),
    );
  }

  void _paintCompass(Canvas canvas, SkyProjection projection, Rect bounds) {
    final visible = bounds.inflate(20);
    for (var degrees = 15; degrees < 360; degrees += 15) {
      if (degrees % 45 == 0) {
        continue;
      }
      final point = projection.project(
        Vec3.fromHorizontal(azimuth: degrees * _degrees, altitude: 0),
      );
      if (point == null || !visible.contains(point)) {
        continue;
      }
      canvas.drawLine(
        point - const Offset(0, 5),
        point + const Offset(0, 5),
        Paint()
          ..strokeWidth = 1.4
          ..color = Colors.white,
      );
      final text = _text(
        '$degrees°',
        const TextStyle(
          color: Colors.white,
          fontSize: 10.5,
          fontWeight: FontWeight.w600,
          shadows: [Shadow(blurRadius: 3)],
        ),
      );
      text.paint(canvas, point + Offset(-text.width / 2, 8));
    }
    for (var index = 0; index < _compassLabels.length; index++) {
      final point = projection.project(
        Vec3.fromHorizontal(azimuth: index * 45 * _degrees, altitude: 0),
      );
      if (point == null || !visible.contains(point)) {
        continue;
      }
      final label = _compassLabels[index];
      final isNorth = index == 0;
      canvas.drawCircle(
        point,
        15,
        Paint()..color = (isNorth ? const Color(0xFFE53935) : _pillColor),
      );
      canvas.drawCircle(
        point,
        15,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.4
          ..color = Colors.white,
      );
      final text = _text(
        label,
        TextStyle(
          color: Colors.white,
          fontSize: label.length > 1 ? 10.5 : 12.5,
          fontWeight: FontWeight.w800,
        ),
      );
      text.paint(canvas, point - Offset(text.width / 2, text.height / 2));
    }
  }

  void _paintPath(Canvas canvas, SkyProjection projection, SunScene scene) {
    final above = Path();
    final below = Path();
    final run = <Vec3>[];
    bool? runAbove;

    void flush() {
      if (run.length > 1) {
        projection.addPolyline(runAbove! ? above : below, run);
      }
    }

    SunPosition? previous;
    for (final position in scene.path) {
      final isAbove = position.altitude >= 0;
      if (previous != null && runAbove != isAbove) {
        final t = previous.altitude / (previous.altitude - position.altitude);
        final crossing = Vec3.lerp(
          previous.direction,
          position.direction,
          t,
        ).normalized();
        run.add(crossing);
        flush();
        run
          ..clear()
          ..add(crossing);
      }
      runAbove = isAbove;
      run.add(position.direction);
      previous = position;
    }
    flush();

    canvas.drawPath(
      below,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6
        ..color = _pathColor.withValues(alpha: 0.35),
    );
    canvas.drawPath(
      above,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5
        ..color = Colors.black.withValues(alpha: 0.18),
    );
    canvas.drawPath(
      above,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.6
        ..strokeCap = StrokeCap.round
        ..color = _pathColor,
    );
  }

  void _paintHourMarkers(
    Canvas canvas,
    SkyProjection projection,
    SunScene scene,
    Rect bounds,
  ) {
    final visible = bounds.inflate(40);
    for (final marker in scene.hourMarkers) {
      final point = projection.project(marker.position.direction);
      final ahead = projection.project(marker.ahead);
      if (point == null || ahead == null || !visible.contains(point)) {
        continue;
      }
      final isAbove = marker.position.altitude >= 0;
      final opacity = isAbove ? 1.0 : 0.45;
      canvas.drawCircle(
        point,
        4.5,
        Paint()..color = _markerColor.withValues(alpha: opacity),
      );
      _paintFlagLabel(
        canvas,
        anchor: point,
        tangent: ahead - point,
        text: formatTime(marker.position.time),
        preferUp: true,
        opacity: opacity,
      );
    }
  }

  void _paintSunEvents(
    Canvas canvas,
    SkyProjection projection,
    SunScene scene,
    Rect bounds,
  ) {
    final visible = bounds.inflate(40);
    for (final (event, name) in [
      (scene.sunrise, 'Sunrise'),
      (scene.sunset, 'Sunset'),
    ]) {
      if (event == null) {
        continue;
      }
      final point = projection.project(event.direction);
      if (point == null || !visible.contains(point)) {
        continue;
      }
      canvas.drawCircle(point, 6, Paint()..color = _sunriseColor);
      canvas.drawCircle(
        point,
        6,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5
          ..color = Colors.white,
      );
      _paintPill(
        canvas,
        center: point + const Offset(0, 24),
        text: '$name ${formatTime(event.time)}',
        color: _sunriseColor.withValues(alpha: 0.92),
      );
    }
  }

  void _paintSun(
    Canvas canvas,
    SkyProjection projection,
    SunPosition sun,
    Rect bounds,
  ) {
    final direction = sun.direction;
    final camera = projection.toCamera(direction);
    final center = camera.z > SkyProjection.nearPlane
        ? projection.projectCamera(camera)
        : null;
    final indicatorBounds = overlayInsets.deflateRect(bounds).deflate(28);
    if (center == null || !indicatorBounds.contains(center)) {
      _paintOffscreenIndicator(canvas, camera, indicatorBounds, sun);
      if (center == null || !bounds.inflate(60).contains(center)) {
        return;
      }
    }

    final outline = _discOutline(projection, direction, sun.angularRadius);
    if (outline == null) {
      return;
    }
    final radius = projection.focalLength * math.tan(sun.angularRadius);
    final isAbove = sun.isAboveHorizon;
    final sunRadius = math.max(radius * 4, 34.0);
    final sunCircle = Rect.fromCircle(center: center, radius: sunRadius);

    canvas.drawCircle(
      center,
      sunRadius,
      Paint()
        ..shader = RadialGradient(
          colors: [
            Colors.white.withValues(alpha: isAbove ? 0.9 : 0.45),
            const Color(0xFFFFE9A8).withValues(alpha: isAbove ? 0.75 : 0.35),
            const Color(0xFFFFD45C).withValues(alpha: isAbove ? 0.6 : 0.3),
          ],
          stops: const [0, 0.5, 1],
        ).createShader(sunCircle),
    );
    canvas.drawCircle(
      center,
      sunRadius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5
        ..color = Colors.black.withValues(alpha: 0.3),
    );
    canvas.drawCircle(
      center,
      sunRadius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..color = isAbove ? _pathColor : Colors.white70,
    );

    canvas.drawPath(
      outline,
      Paint()..color = const Color(0xFFFFF3C4).withValues(alpha: 0.35),
    );
    canvas.drawPath(
      outline,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6
        ..color = isAbove ? const Color(0xFFFF3B30) : Colors.white70,
    );

    final tickPaint = Paint()
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..color = Colors.white.withValues(alpha: 0.9);
    final inner = sunRadius + 5;
    final outer = sunRadius + 12;
    for (var quarter = 0; quarter < 4; quarter++) {
      final angle = quarter * math.pi / 2 + math.pi / 4;
      final unit = Offset(math.cos(angle), math.sin(angle));
      canvas.drawLine(center + unit * inner, center + unit * outer, tickPaint);
    }

    final ahead = projection.project(
      Vec3.fromHorizontal(azimuth: sun.azimuth + 0.01, altitude: sun.altitude),
    );
    _paintFlagLabel(
      canvas,
      anchor: center,
      tangent: ahead == null ? const Offset(1, 0) : ahead - center,
      text: formatTime(sun.time),
      preferUp: false,
      opacity: 1,
      gap: outer + 4,
    );
  }

  Path? _discOutline(
    SkyProjection projection,
    Vec3 direction,
    double angularRadius,
  ) {
    final reference = direction.z.abs() < 0.9
        ? const Vec3(0, 0, 1)
        : const Vec3(1, 0, 0);
    final u = direction.cross(reference).normalized();
    final v = direction.cross(u).normalized();
    final cosRadius = math.cos(angularRadius);
    final sinRadius = math.sin(angularRadius);
    final path = Path();
    const segments = 48;
    for (var index = 0; index <= segments; index++) {
      final angle = index / segments * 2 * math.pi;
      final point = projection.project(
        direction * cosRadius +
            (u * math.cos(angle) + v * math.sin(angle)) * sinRadius,
      );
      if (point == null) {
        return null;
      }
      if (index == 0) {
        path.moveTo(point.dx, point.dy);
      } else {
        path.lineTo(point.dx, point.dy);
      }
    }
    return path..close();
  }

  void _paintOffscreenIndicator(
    Canvas canvas,
    Vec3 camera,
    Rect area,
    SunPosition sun,
  ) {
    var direction = Offset(camera.x, -camera.y);
    if (direction.distance < 1e-6) {
      direction = const Offset(0, 1);
    }
    direction = direction / direction.distance;
    final center = area.center;
    final scaleX = direction.dx.abs() < 1e-6
        ? double.infinity
        : (area.width / 2) / direction.dx.abs();
    final scaleY = direction.dy.abs() < 1e-6
        ? double.infinity
        : (area.height / 2) / direction.dy.abs();
    final position = center + direction * math.min(scaleX, scaleY);

    final angle = math.atan2(direction.dy, direction.dx);
    canvas.save();
    canvas.translate(position.dx, position.dy);
    canvas.rotate(angle);
    canvas.drawPath(
      Path()
        ..moveTo(30, 0)
        ..lineTo(18, -9)
        ..lineTo(18, 9)
        ..close(),
      Paint()..color = _pathColor,
    );
    canvas.restore();

    canvas.drawCircle(position, 18, Paint()..color = _pillColor);
    canvas.drawCircle(
      position,
      18,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..color = _pathColor,
    );
    canvas.drawCircle(
      position,
      7,
      Paint()
        ..color = sun.isAboveHorizon
            ? _pathColor
            : _pathColor.withValues(alpha: 0.7),
    );
  }

  /// Draws a label that sticks out sideways from a curve at [anchor], with its
  /// text running perpendicular to the curve like in a sun path diagram.
  void _paintFlagLabel(
    Canvas canvas, {
    required Offset anchor,
    required Offset tangent,
    required String text,
    required bool preferUp,
    required double opacity,
    double gap = 10,
  }) {
    if (tangent.distance < 1e-6) {
      tangent = const Offset(1, 0);
    }
    final unitTangent = tangent / tangent.distance;
    var normal = Offset(-unitTangent.dy, unitTangent.dx);
    if ((normal.dy < 0) != preferUp) {
      normal = -normal;
    }
    final painter = _text(
      text,
      const TextStyle(
        color: Colors.white,
        fontSize: 11.5,
        fontWeight: FontWeight.w700,
      ),
    );
    final pillWidth = painter.width + 14;
    final pillHeight = painter.height + 6;
    final center = anchor + normal * (gap + pillWidth / 2);

    var angle = math.atan2(normal.dy, normal.dx);
    if (angle > math.pi / 2) {
      angle -= math.pi;
    } else if (angle < -math.pi / 2) {
      angle += math.pi;
    }

    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(angle);
    final rect = Rect.fromCenter(
      center: Offset.zero,
      width: pillWidth,
      height: pillHeight,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, Radius.circular(pillHeight / 2)),
      Paint()..color = _pillColor.withValues(alpha: 0.85 * opacity),
    );
    final translucent = opacity < 1;
    if (translucent) {
      canvas.saveLayer(
        rect,
        Paint()..color = Colors.white.withValues(alpha: opacity),
      );
    }
    painter.paint(canvas, Offset(-painter.width / 2, -painter.height / 2));
    if (translucent) {
      canvas.restore();
    }
    canvas.restore();
  }

  void _paintPill(
    Canvas canvas, {
    required Offset center,
    required String text,
    required Color color,
  }) {
    final painter = _text(
      text,
      const TextStyle(
        color: Colors.white,
        fontSize: 11.5,
        fontWeight: FontWeight.w700,
      ),
    );
    final rect = Rect.fromCenter(
      center: center,
      width: painter.width + 16,
      height: painter.height + 8,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, Radius.circular(rect.height / 2)),
      Paint()..color = color,
    );
    painter.paint(
      canvas,
      center - Offset(painter.width / 2, painter.height / 2),
    );
  }

  TextPainter _text(String text, TextStyle style) {
    final key = '${style.hashCode}|$text';
    final cached = _textCache[key];
    if (cached != null) {
      return cached;
    }
    if (_textCache.length > 400) {
      _textCache.clear();
    }
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: style.copyWith(fontFamily: 'Roboto'),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    return _textCache[key] = painter;
  }

  @override
  bool shouldRepaint(SkyPainter oldDelegate) =>
      oldDelegate.orientation != orientation ||
      oldDelegate.northOffset != northOffset ||
      oldDelegate.focalLength != focalLength ||
      oldDelegate.scene != scene ||
      oldDelegate.selected != selected ||
      oldDelegate.overlayInsets != overlayInsets;
}
