import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:provider/provider.dart';

import 'core/global_keys.dart';
import 'providers/device_provider.dart';
import 'providers/user_provider.dart';
import 'providers/water_provider.dart';
import 'ui/pages/home_page.dart';
import 'ui/pages/login_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  await Hive.openBox('water_history_box');
  HttpOverrides.global = MyHttpOverrides();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<UserProvider>(create: (_) => UserProvider()),
        ChangeNotifierProvider<DeviceProvider>(create: (_) => DeviceProvider()),
        ChangeNotifierProvider<WaterProvider>(create: (_) => WaterProvider()),
      ],
      child: const WaterApp(),
    ),
  );
}

class MyHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return super.createHttpClient(context)
      ..badCertificateCallback =
          (X509Certificate cert, String host, int port) => true;
  }
}

class WaterApp extends StatefulWidget {
  const WaterApp({super.key});

  @override
  State<WaterApp> createState() => _WaterAppState();
}

class _WaterAppState extends State<WaterApp> with WidgetsBindingObserver {
  bool _isSyncingExternalWaterSession = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initApp();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_syncExternalWaterSession(syncHistoryAfterChange: true));
    }
  }

  Future<void> _initApp() async {
    final userProvider = context.read<UserProvider>();
    final deviceProvider = context.read<DeviceProvider>();
    final waterProvider = context.read<WaterProvider>();

    await userProvider.loadFromLocal();
    if (!mounted) {
      return;
    }

    await deviceProvider.loadFromLocal(userProvider.token, userProvider.userId);
    if (!mounted) {
      return;
    }

    await waterProvider.loadFromLocal();
    if (!mounted) {
      return;
    }

    await _syncExternalWaterSession();
    if (!mounted) {
      return;
    }

    if (userProvider.token.isNotEmpty && userProvider.userId.isNotEmpty) {
      await waterProvider.syncHistoryFromServer(
        token: userProvider.token,
        userId: userProvider.userId,
        muteToast: true,
      );
      if (!mounted) {
        return;
      }

      unawaited(
        waterProvider.backfillHistoryIfNeeded(
          token: userProvider.token,
          userId: userProvider.userId,
        ),
      );
    }
  }

  Future<void> _syncExternalWaterSession({
    bool syncHistoryAfterChange = false,
  }) async {
    if (_isSyncingExternalWaterSession || !mounted) {
      return;
    }

    _isSyncingExternalWaterSession = true;
    try {
      final userProvider = context.read<UserProvider>();
      final waterProvider = context.read<WaterProvider>();
      final changed = await waterProvider.syncExternalWaterSession(
        currentBalance: userProvider.balance,
        onBalanceUpdated: userProvider.setBalance,
      );
      if (!mounted || !changed || !syncHistoryAfterChange) {
        return;
      }
      if (userProvider.token.isEmpty || userProvider.userId.isEmpty) {
        return;
      }
      await waterProvider.syncHistoryFromServer(
        token: userProvider.token,
        userId: userProvider.userId,
        muteToast: true,
      );
    } finally {
      _isSyncingExternalWaterSession = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      debugShowCheckedModeBanner: false,
      title: 'UY Water',
      theme: ThemeData(primarySwatch: Colors.blue, useMaterial3: true),
      home: Consumer<UserProvider>(
        builder: (context, userProvider, child) {
          if (userProvider.token.isEmpty) {
            return const LoginPage();
          }
          return const HomePage();
        },
      ),
    );
  }
}
