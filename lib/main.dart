import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sun_tracker/src/settings/calibration.dart';
import 'package:sun_tracker/src/ui/ar_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  final calibration = await Calibration.load();
  runApp(SunTrackerApp(calibration: calibration));
}

const _seedColor = Color(0xFFF5A623);

class SunTrackerApp extends StatelessWidget {
  const SunTrackerApp({required this.calibration, super.key});

  final Calibration calibration;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Sun Tracker',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.system,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: _seedColor),
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: _seedColor,
          brightness: Brightness.dark,
        ),
      ),
      home: ArScreen(calibration: calibration),
    );
  }
}
