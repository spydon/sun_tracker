import 'dart:math' as math;

import 'package:sun_tracker/src/math/vec3.dart';

const double _degrees = math.pi / 180;

/// The altitude of the sun's center at sunrise and sunset, accounting for
/// atmospheric refraction and the sun's apparent radius.
const double sunriseAltitude = -0.833 * _degrees;

class SunPosition {
  const SunPosition({
    required this.time,
    required this.azimuth,
    required this.altitude,
    required this.angularRadius,
  });

  final DateTime time;

  /// Radians clockwise from true north.
  final double azimuth;

  /// Apparent altitude in radians, including atmospheric refraction.
  final double altitude;

  /// Apparent angular radius of the solar disc in radians.
  final double angularRadius;

  Vec3 get direction =>
      Vec3.fromHorizontal(azimuth: azimuth, altitude: altitude);

  bool get isAboveHorizon => altitude > -angularRadius;
}

enum DayKind { normal, midnightSun, polarNight }

class SunDay {
  const SunDay({required this.kind, this.sunrise, this.sunset});

  final DayKind kind;
  final DateTime? sunrise;
  final DateTime? sunset;

  Duration? get dayLength {
    final rise = sunrise;
    final set = sunset;
    if (rise != null && set != null && set.isAfter(rise)) {
      return set.difference(rise);
    }
    return switch (kind) {
      DayKind.midnightSun => const Duration(hours: 24),
      DayKind.polarNight => Duration.zero,
      DayKind.normal => null,
    };
  }
}

class SunCalculator {
  const SunCalculator({required this.latitude, required this.longitude});

  /// Degrees, positive north.
  final double latitude;

  /// Degrees, positive east.
  final double longitude;

  SunPosition positionAt(DateTime time) {
    final geometric = _geometricPosition(time);
    return SunPosition(
      time: time,
      azimuth: geometric.azimuth,
      altitude: geometric.altitude + _refraction(geometric.altitude),
      angularRadius: geometric.angularRadius,
    );
  }

  /// Finds sunrise and sunset for the local calendar day containing [day].
  SunDay dayOf(DateTime day) {
    final start = DateTime(day.year, day.month, day.day);
    final end = DateTime(day.year, day.month, day.day + 1);
    const step = Duration(minutes: 10);

    DateTime? sunrise;
    DateTime? sunset;
    var anyAbove = false;
    var allAbove = true;

    var previousTime = start;
    var previousValue = _geometricAltitude(start) - sunriseAltitude;
    while (previousTime.isBefore(end)) {
      var time = previousTime.add(step);
      if (time.isAfter(end)) {
        time = end;
      }
      final value = _geometricAltitude(time) - sunriseAltitude;
      if (previousValue > 0 || value > 0) {
        anyAbove = true;
      }
      if (previousValue <= 0 || value <= 0) {
        allAbove = false;
      }
      if (previousValue <= 0 && value > 0) {
        sunrise ??= _refineCrossing(previousTime, time);
      } else if (previousValue > 0 && value <= 0) {
        sunset ??= _refineCrossing(previousTime, time);
      }
      previousTime = time;
      previousValue = value;
    }

    final kind = sunrise != null || sunset != null
        ? DayKind.normal
        : allAbove
        ? DayKind.midnightSun
        : anyAbove
        ? DayKind.normal
        : DayKind.polarNight;
    return SunDay(kind: kind, sunrise: sunrise, sunset: sunset);
  }

  /// Samples the sun's position over the local calendar day containing [day].
  List<SunPosition> pathOf(
    DateTime day, {
    Duration step = const Duration(minutes: 5),
  }) {
    final start = DateTime(day.year, day.month, day.day);
    final end = DateTime(day.year, day.month, day.day + 1);
    final positions = <SunPosition>[];
    var time = start;
    while (!time.isAfter(end)) {
      positions.add(positionAt(time));
      time = time.add(step);
    }
    return positions;
  }

  DateTime _refineCrossing(DateTime a, DateTime b) {
    var low = a.millisecondsSinceEpoch;
    var high = b.millisecondsSinceEpoch;
    final lowRising = _altitudeAtMillis(low) <= sunriseAltitude;
    while (high - low > 1000) {
      final mid = (low + high) ~/ 2;
      final midBelow = _altitudeAtMillis(mid) <= sunriseAltitude;
      if (midBelow == lowRising) {
        low = mid;
      } else {
        high = mid;
      }
    }
    return DateTime.fromMillisecondsSinceEpoch(high);
  }

  double _altitudeAtMillis(int millis) =>
      _geometricAltitude(DateTime.fromMillisecondsSinceEpoch(millis));

  double _geometricAltitude(DateTime time) => _geometricPosition(time).altitude;

  _GeometricPosition _geometricPosition(DateTime time) {
    final julianDay =
        time.toUtc().millisecondsSinceEpoch / 86400000 + 2440587.5;
    final t = (julianDay - 2451545) / 36525;

    final meanLongitude = _normalizeDegrees(
      280.46646 + t * (36000.76983 + t * 0.0003032),
    );
    final meanAnomaly = 357.52911 + t * (35999.05029 - 0.0001537 * t);
    final eccentricity = 0.016708634 - t * (0.000042037 + 0.0000001267 * t);
    final m = meanAnomaly * _degrees;
    final equationOfCenter =
        math.sin(m) * (1.914602 - t * (0.004817 + 0.000014 * t)) +
        math.sin(2 * m) * (0.019993 - 0.000101 * t) +
        math.sin(3 * m) * 0.000289;
    final trueLongitude = meanLongitude + equationOfCenter;
    final trueAnomaly = (meanAnomaly + equationOfCenter) * _degrees;
    final distance =
        1.000001018 *
        (1 - eccentricity * eccentricity) /
        (1 + eccentricity * math.cos(trueAnomaly));

    final omega = (125.04 - 1934.136 * t) * _degrees;
    final apparentLongitude =
        (trueLongitude - 0.00569 - 0.00478 * math.sin(omega)) * _degrees;
    final meanObliquity =
        23 +
        (26 + (21.448 - t * (46.815 + t * (0.00059 - t * 0.001813))) / 60) / 60;
    final obliquity = (meanObliquity + 0.00256 * math.cos(omega)) * _degrees;

    final declination = math.asin(
      math.sin(obliquity) * math.sin(apparentLongitude),
    );
    final rightAscension = math.atan2(
      math.cos(obliquity) * math.sin(apparentLongitude),
      math.cos(apparentLongitude),
    );

    final daysSinceJ2000 = julianDay - 2451545;
    final siderealTime = _normalizeDegrees(
      280.46061837 +
          360.98564736629 * daysSinceJ2000 +
          0.000387933 * t * t -
          t * t * t / 38710000,
    );
    final hourAngle = (siderealTime + longitude) * _degrees - rightAscension;

    final lat = latitude * _degrees;
    final altitude = math.asin(
      (math.sin(lat) * math.sin(declination) +
              math.cos(lat) * math.cos(declination) * math.cos(hourAngle))
          .clamp(-1.0, 1.0),
    );
    final azimuth = math.atan2(
      -math.sin(hourAngle) * math.cos(declination),
      math.sin(declination) * math.cos(lat) -
          math.cos(declination) * math.sin(lat) * math.cos(hourAngle),
    );

    return _GeometricPosition(
      azimuth: _normalizeRadians(azimuth),
      altitude: altitude,
      angularRadius: (959.63 / 3600) * _degrees / distance,
    );
  }

  /// Atmospheric refraction in radians for a geometric altitude, using
  /// Sæmundsson's formula.
  static double _refraction(double geometricAltitude) {
    final altitudeDegrees = geometricAltitude / _degrees;
    final h = math.max(altitudeDegrees, -1.5);
    final arcMinutes = 1.02 / math.tan((h + 10.3 / (h + 5.11)) * _degrees);
    final fade = altitudeDegrees < -1.5
        ? math.max(0.0, 1 + (altitudeDegrees + 1.5) / 2)
        : 1.0;
    return math.max(arcMinutes, 0) * fade / 60 * _degrees;
  }

  static double _normalizeDegrees(double value) {
    final result = value % 360;
    return result < 0 ? result + 360 : result;
  }

  static double _normalizeRadians(double value) {
    final result = value % (2 * math.pi);
    return result < 0 ? result + 2 * math.pi : result;
  }
}

class _GeometricPosition {
  const _GeometricPosition({
    required this.azimuth,
    required this.altitude,
    required this.angularRadius,
  });

  final double azimuth;
  final double altitude;
  final double angularRadius;
}
