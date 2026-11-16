import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:sun_tracker/src/astronomy/sun_calculator.dart';

double _degrees(double radians) => radians * 180 / math.pi;

void main() {
  group('SunCalculator', () {
    const stockholm = SunCalculator(latitude: 59.3293, longitude: 18.0686);
    const tromso = SunCalculator(latitude: 69.6492, longitude: 18.9553);
    const greenwich = SunCalculator(latitude: 51.4769, longitude: 0);

    test('finds midsummer sunrise and sunset in Stockholm', () {
      final day = stockholm.dayOf(DateTime(2026, 6, 21, 12));
      expect(day.kind, DayKind.normal);
      final sunrise = day.sunrise!.toUtc();
      final sunset = day.sunset!.toUtc();
      final expectedSunrise = DateTime.utc(2026, 6, 21, 1, 31);
      final expectedSunset = DateTime.utc(2026, 6, 21, 20, 8);
      expect(
        sunrise.difference(expectedSunrise).inMinutes.abs(),
        lessThanOrEqualTo(3),
      );
      expect(
        sunset.difference(expectedSunset).inMinutes.abs(),
        lessThanOrEqualTo(3),
      );
    });

    test('detects midnight sun and polar night in Tromsø', () {
      expect(tromso.dayOf(DateTime(2026, 6, 21)).kind, DayKind.midnightSun);
      expect(tromso.dayOf(DateTime(2026, 12, 21)).kind, DayKind.polarNight);
      expect(
        tromso.dayOf(DateTime(2026, 6, 21)).dayLength,
        const Duration(hours: 24),
      );
    });

    test('places the sun due south at solar noon on the equinox', () {
      final noon = greenwich.positionAt(DateTime.utc(2026, 3, 20, 12, 7));
      expect(_degrees(noon.azimuth), closeTo(180, 1));
      expect(_degrees(noon.altitude), closeTo(90 - 51.4769, 0.5));
    });

    test(
      'puts the morning sun in the east and the evening sun in the west',
      () {
        final morning = stockholm.positionAt(DateTime.utc(2026, 9, 1, 6));
        final evening = stockholm.positionAt(DateTime.utc(2026, 9, 1, 16));
        expect(_degrees(morning.azimuth), inExclusiveRange(45, 135));
        expect(_degrees(evening.azimuth), inExclusiveRange(225, 315));
      },
    );

    test('computes the apparent size of the sun', () {
      final january = stockholm.positionAt(DateTime.utc(2026, 1, 3));
      final july = stockholm.positionAt(DateTime.utc(2026, 7, 4));
      expect(_degrees(january.angularRadius), closeTo(0.2717, 0.001));
      expect(_degrees(july.angularRadius), closeTo(0.2624, 0.001));
    });

    test('samples a full day of positions', () {
      final path = stockholm.pathOf(DateTime(2026, 6, 21));
      expect(path.length, greaterThanOrEqualTo(24 * 12));
      final highest = path
          .map((position) => position.altitude)
          .reduce(math.max);
      expect(_degrees(highest), closeTo(90 - 59.3293 + 23.44, 0.5));
    });
  });
}
