import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/theme/app_theme.dart';
import 'providers/vpn_provider.dart';
import 'providers/config_provider.dart';
import 'providers/log_provider.dart';
import 'presentation/screens/home_screen.dart';
import 'presentation/screens/privacy_policy_screen.dart';
import 'presentation/screens/payload_builder_screen.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final configProvider = ConfigProvider();

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    debugPrint("Firebase init error: \$e");
  }

  try {
    // Load persisted configs
    await configProvider.loadAll();
  } catch (e) {
    debugPrint("Config Provider load error: \$e");
  }

  try {
    // Initialize OneSignal
    OneSignal.Debug.setLogLevel(OSLogLevel.verbose);
    OneSignal.initialize("38488f6b-222c-48ed-aee1-702302054ca9");
    OneSignal.Notifications.requestPermission(true);
  } catch (e) {
    debugPrint("OneSignal init error: \$e");
  }

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => configProvider),
        ChangeNotifierProvider(create: (_) => VpnProvider()),
        ChangeNotifierProvider(create: (_) => LogProvider()),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
      ],
      child: const VpnMasterApp(),
    ),
  );
}

class VpnMasterApp extends StatelessWidget {
  const VpnMasterApp({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();

    return MaterialApp(
      title: 'Velora VPN Proxy',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: theme.themeMode,
      initialRoute: '/',
      routes: {
        '/': (_) => const HomeScreen(),
        '/privacy': (_) => const PrivacyPolicyScreen(),
        '/payload': (_) => const PayloadBuilderScreen(),
      },
    );
  }
}
