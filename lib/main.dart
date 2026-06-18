import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'models/layout_notifier.dart';
import 'screens/gamepad_screen.dart';
import 'services/connectivity_service.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Lock the application to landscape mode natively
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeRight,
    DeviceOrientation.landscapeLeft,
  ]).then((_) {
    runApp(const GamepadApp());
  });
}

class GamepadApp extends StatelessWidget {
  const GamepadApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Inject the state provider at the very top of the widget tree
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => LayoutNotifier()),
        ChangeNotifierProvider(create: (_) => ConnectivityService()),
      ],
      child: ScreenUtilInit(
        // Flipped to Landscape dimensions (Width: 844, Height: 390)
        designSize: const Size(844, 390),
        minTextAdapt: true,
        builder: (context, child) {
          return MaterialApp(
            title: 'Beast Controller',
            debugShowCheckedModeBanner: false,
            theme: ThemeData.dark(),
            home: const GamepadScreen(),
          );
        },
      ),
    );
  }
}