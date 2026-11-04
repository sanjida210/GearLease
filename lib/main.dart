import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'core/di/injection_container.dart' as di;
import 'core/theme/app_theme.dart';
import 'features/shell/presentation/screens/main_shell_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize dependency injection
  await di.initDependencies();

  // Set system UI overlay style for dark industrial aesthetic
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Color(0xFF090D14),
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  runApp(const GearLeaseApp());
}

class GearLeaseApp extends StatelessWidget {
  const GearLeaseApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'GearLease Mobile',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      home: const MainShellScreen(),
    );
  }
}
