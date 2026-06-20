import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'models/layout_notifier.dart';
import 'providers/theme_notifier.dart';
import 'screens/gamepad_screen.dart';
import 'services/connectivity_service.dart';
import 'theme/app_theme.dart';
import 'providers/settings_notifier.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load SharedPreferences before rendering any UI to prevent null pointer exceptions
  final prefs = await SharedPreferences.getInstance();

  // Lock the application to landscape mode natively
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeRight,
    DeviceOrientation.landscapeLeft,
  ]);

  // Enforce Immersive Sticky Mode for gamepads to prevent accidental edge-swipes
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

  // All async initialization complete; now render the app
  runApp(GamepadApp(prefs: prefs));
}

class GamepadApp extends StatelessWidget {
  final SharedPreferences prefs;

  const GamepadApp({Key? key, required this.prefs}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Inject the state providers at the very top of the widget tree
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeNotifier()),
        ChangeNotifierProvider(create: (_) => LayoutNotifier(prefs)),
        ChangeNotifierProvider(create: (_) => ConnectivityService()),
        ChangeNotifierProvider(create: (_) => SettingsNotifier(prefs)),
      ],
      child: ScreenUtilInit(
        // Flipped to Landscape dimensions (Width: 844, Height: 390)
        designSize: const Size(844, 390),
        minTextAdapt: true,
        builder: (context, child) {
          return MaterialApp(
            title: 'CTRLFORGE',
            debugShowCheckedModeBanner: false,
            theme: ThemeData(
              scaffoldBackgroundColor: AppTheme.kBackground,
              brightness: Brightness.dark,
            ),
            home: const GamepadScreen(),
          );
        },
      ),
    );
  }
}