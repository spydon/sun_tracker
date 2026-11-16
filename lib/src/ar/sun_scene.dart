import 'package:sun_tracker/src/astronomy/sun_calculator.dart';
import 'package:sun_tracker/src/math/vec3.dart';

class HourMarker {
  const HourMarker({required this.position, required this.ahead});

  final SunPosition position;

  /// The sun's direction a little later, used to orient the label.
  final Vec3 ahead;
}

/// Everything that only depends on the location and the calendar day.
class SunScene {
  const SunScene({
    required this.path,
    required this.hourMarkers,
    required this.day,
    required this.sunrise,
    required this.sunset,
  });

  factory SunScene.compute(SunCalculator calculator, DateTime date) {
    final day = calculator.dayOf(date);
    final hourMarkers = <HourMarker>[
      for (var hour = 0; hour < 24; hour++)
        HourMarker(
          position: calculator.positionAt(
            DateTime(date.year, date.month, date.day, hour),
          ),
          ahead: calculator
              .positionAt(DateTime(date.year, date.month, date.day, hour, 10))
              .direction,
        ),
    ];
    final sunrise = day.sunrise;
    final sunset = day.sunset;
    return SunScene(
      path: calculator.pathOf(date),
      hourMarkers: hourMarkers,
      day: day,
      sunrise: sunrise == null ? null : calculator.positionAt(sunrise),
      sunset: sunset == null ? null : calculator.positionAt(sunset),
    );
  }

  final List<SunPosition> path;
  final List<HourMarker> hourMarkers;
  final SunDay day;
  final SunPosition? sunrise;
  final SunPosition? sunset;
}
