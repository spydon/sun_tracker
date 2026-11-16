import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_rotation_sensor/flutter_rotation_sensor.dart'
    as rotation_sensor;
import 'package:sun_tracker/src/math/vec3.dart';

/// Smoothed device orientation from the fused rotation vector sensor.
class DeviceOrientationSource extends ChangeNotifier {
  DeviceOrientationSource({this.smoothing = 0.25});

  final double smoothing;

  StreamSubscription<rotation_sensor.OrientationEvent>? _subscription;
  Quaternion? _rotation;
  Matrix3 _matrix = Matrix3.identity;
  double? _headingAccuracy;
  String? _error;

  bool get hasData => _rotation != null;

  /// Row major matrix mapping device coordinates to the East, North, Up frame
  /// referenced to magnetic north.
  Matrix3 get deviceToWorld => _matrix;

  /// Estimated heading error in radians, or null when the sensor does not
  /// report it.
  double? get headingAccuracy => _headingAccuracy;

  String? get error => _error;

  void start() {
    if (_subscription != null) {
      return;
    }
    rotation_sensor.RotationSensor.coordinateSystem =
        rotation_sensor.CoordinateSystem.device();
    rotation_sensor.RotationSensor.referenceFrame =
        rotation_sensor.ReferenceFrame.magneticNorth;
    rotation_sensor.RotationSensor.samplingPeriod =
        rotation_sensor.SensorInterval.gameInterval;
    _subscription = rotation_sensor.RotationSensor.orientationStream.listen(
      _onEvent,
      onError: _onError,
    );
  }

  void stop() {
    _subscription?.cancel();
    _subscription = null;
  }

  void _onEvent(rotation_sensor.OrientationEvent event) {
    final q = event.quaternion;
    final sample = Quaternion(q.w, q.x, q.y, q.z).normalized();
    final previous = _rotation;
    final rotation = previous == null
        ? sample
        : previous.nlerp(sample, smoothing);
    _rotation = rotation;
    _matrix = rotation.toMatrix();
    _headingAccuracy = event.accuracy >= 0 ? event.accuracy : null;
    _error = null;
    notifyListeners();
  }

  void _onError(Object error) {
    _error = 'Orientation sensor unavailable: $error';
    notifyListeners();
  }

  @override
  void dispose() {
    stop();
    super.dispose();
  }
}
