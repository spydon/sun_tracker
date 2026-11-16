<p align="center"><img src="assets/logo/logo.svg" width="160" alt="Sun Tracker logo"></p>

# Sun Tracker

An Android augmented reality app that shows where the sun is, or will be, on the sky at your location.

- Camera view with an altitude and azimuth grid, the horizon and compass directions.
- The sun's path for the selected day with hourly markers, sunrise and sunset.
- The sun drawn as its real outline at true angular size. Pinch to zoom in on it, double tap to reset.
- Scrub the day and time rulers, or pick a date, to see any other time or season.
- An arrow at the screen edge points towards the sun when it is out of view.

Orientation comes from Android's fused rotation vector sensor through [flutter_rotation_sensor](https://pub.dev/packages/flutter_rotation_sensor), corrected to true north with the World Magnetic Model from [geomag](https://pub.dev/packages/geomag). The camera's field of view is read from the device. Both can be fine tuned in the calibration sheet.

The logo source files are in `assets/logo`.

```sh
flutter run
flutter test
```
