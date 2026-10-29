import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'app_controller.dart';
import 'ui/home.dart';
import 'theme/terax_theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  LicenseRegistry.addLicense(() async* {
    yield LicenseEntryWithLineBreaks([
      'Figtree',
    ], await rootBundle.loadString('assets/fonts/Figtree-OFL.txt'));
    yield LicenseEntryWithLineBreaks([
      'Geist Mono',
    ], await rootBundle.loadString('assets/fonts/GeistMono-OFL.txt'));
  });
  runApp(const TeraxApp());
}

ThemeData teraxTheme() => TeraxTheme.build(TeraxPlatform.current);

class TeraxApp extends StatefulWidget {
  const TeraxApp({super.key});
  @override
  State<TeraxApp> createState() => _TeraxAppState();
}

class _TeraxAppState extends State<TeraxApp> with WidgetsBindingObserver {
  final controller = AppController();
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    controller.initialize();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Terax',
    debugShowCheckedModeBanner: false,
    theme: teraxTheme(),
    home: Home(controller: controller),
  );

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) controller.resumeProximity();
  }
}
