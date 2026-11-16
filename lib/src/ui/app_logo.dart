import 'package:material_ui/material_ui.dart';

class AppLogo extends StatelessWidget {
  const AppLogo({this.size = 48, super.key});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/logo/logo.png',
      width: size,
      height: size,
      filterQuality: FilterQuality.medium,
      semanticLabel: 'Sun Tracker logo',
    );
  }
}
