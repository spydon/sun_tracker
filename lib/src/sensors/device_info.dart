import 'package:flutter/services.dart';
import 'package:geomag/geomag.dart';

class DeviceInfo {
  const DeviceInfo._();

  static const _channel = MethodChannel('sun_tracker/device');

  static const _feetPerMeter = 3.28084;

  /// Magnetic declination in degrees from the World Magnetic Model, positive
  /// when magnetic north is east of true north.
  static double magneticDeclination({
    required double latitude,
    required double longitude,
    required double altitude,
  }) {
    return GeoMag()
        .calculate(
          latitude,
          longitude,
          altitude * _feetPerMeter,
          DateTime.now(),
        )
        .dec;
  }

  /// The field of view in degrees along the long side of the camera sensor.
  static Future<double?> cameraFieldOfView(String cameraId) async {
    try {
      return await _channel.invokeMethod<double>('cameraFieldOfView', {
        'cameraId': cameraId,
      });
    } on PlatformException {
      return null;
    }
  }
}
