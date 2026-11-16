import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Manual corrections for compass and lens errors, persisted between runs.
class Calibration extends ChangeNotifier {
  Calibration._(this._preferences)
    : _headingOffset = _preferences.getDouble(_headingOffsetKey) ?? 0,
      _fieldOfViewScale = _preferences.getDouble(_fieldOfViewScaleKey) ?? 1;

  static const _headingOffsetKey = 'heading_offset';
  static const _fieldOfViewScaleKey = 'field_of_view_scale';

  static const maxHeadingOffset = 30.0;
  static const minFieldOfViewScale = 0.8;
  static const maxFieldOfViewScale = 1.2;

  static Future<Calibration> load() async {
    return Calibration._(await SharedPreferences.getInstance());
  }

  final SharedPreferences _preferences;
  double _headingOffset;
  double _fieldOfViewScale;

  /// Degrees added to the compass heading.
  double get headingOffset => _headingOffset;

  set headingOffset(double value) {
    _headingOffset = value;
    _preferences.setDouble(_headingOffsetKey, value);
    notifyListeners();
  }

  /// Multiplier applied to the camera field of view.
  double get fieldOfViewScale => _fieldOfViewScale;

  set fieldOfViewScale(double value) {
    _fieldOfViewScale = value;
    _preferences.setDouble(_fieldOfViewScaleKey, value);
    notifyListeners();
  }

  void reset() {
    headingOffset = 0;
    fieldOfViewScale = 1;
  }
}
