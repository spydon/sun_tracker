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

class SunTrackerApp extends StatelessWidget {
  const SunTrackerApp({required this.calibration, super.key});

  final Calibration calibration;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Sun Tracker',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFF5A623),
          brightness: Brightness.dark,
        ),
      ),
      home: ArScreen(calibration: calibration),
    );
  }
}
