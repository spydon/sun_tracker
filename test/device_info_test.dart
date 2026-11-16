import 'package:flutter_test/flutter_test.dart';
import 'package:sun_tracker/src/sensors/device_info.dart';

void main() {
  test('computes a plausible magnetic declination for Stockholm', () {
    final declination = DeviceInfo.magneticDeclination(
      latitude: 59.3293,
      longitude: 18.0686,
      altitude: 20,
    );
    expect(declination, inInclusiveRange(5, 10));
  });
}
