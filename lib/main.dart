import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'core/config/app_config.dart';
import 'core/di/injection_container.dart' as di;
import 'core/theme/app_theme.dart';
import 'features/gear_relay/presentation/bloc/gear_relay_bloc.dart';
import 'features/offline_sync/presentation/bloc/sync_bloc.dart';
import 'features/offline_sync/presentation/bloc/sync_event.dart';
import 'features/quote/presentation/bloc/quote_bloc.dart';
import 'features/scanner/presentation/bloc/scanner_bloc.dart';
import 'features/shell/presentation/screens/main_shell_screen.dart';
import 'features/signature/presentation/bloc/signature_bloc.dart';
import 'features/telemetry/presentation/bloc/telemetry_bloc.dart';

void main() async {
  await runGearLeaseApp(AppConfig.prod);
}

Future<void> runGearLeaseApp(AppConfig config) async {
  WidgetsFlutterBinding.ensureInitialized();

  AppConfig.initialize(config);

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

  runApp(GearLeaseApp(config: config));
}

class GearLeaseApp extends StatelessWidget {
  final AppConfig? config;

  const GearLeaseApp({super.key, this.config});

  @override
  Widget build(BuildContext context) {
    final activeConfig = config ?? AppConfig.instance;

    return MultiBlocProvider(
      providers: [
        BlocProvider<SyncBloc>(
          create: (_) => di.sl<SyncBloc>()..add(SyncWatchStarted()),
        ),
        BlocProvider<TelemetryBloc>(
          create: (_) => di.sl<TelemetryBloc>(),
        ),
        BlocProvider<QuoteBloc>(
          create: (_) => di.sl<QuoteBloc>(),
        ),
        BlocProvider<ScannerBloc>(
          create: (_) => di.sl<ScannerBloc>(),
        ),
        BlocProvider<SignatureBloc>(
          create: (_) => di.sl<SignatureBloc>(),
        ),
        BlocProvider<GearRelayBloc>(
          create: (_) => di.sl<GearRelayBloc>(),
        ),
      ],
      child: MaterialApp(
        title: activeConfig.appTitle,
        debugShowCheckedModeBanner: activeConfig.showDebugBanner,
        theme: AppTheme.darkTheme,
        home: const MainShellScreen(),
      ),
    );
  }
}
